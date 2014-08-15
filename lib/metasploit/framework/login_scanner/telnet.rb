require 'metasploit/framework/telnet/client'
require 'metasploit/framework/login_scanner/base'
require 'metasploit/framework/login_scanner/rex_socket'
module Metasploit
  module Framework
    module LoginScanner

      # This is the LoginScanner class for dealing with Telnet remote terminals.
      # It is responsible for taking a single target, and a list of credentials
      # and attempting them. It then saves the results.
      class Telnet
        include Metasploit::Framework::LoginScanner::Base
        include Metasploit::Framework::LoginScanner::RexSocket
        include Metasploit::Framework::Telnet::Client

        CAN_GET_SESSION      = true
        DEFAULT_PORT         = 23
        LIKELY_PORTS         = [ DEFAULT_PORT ]
        LIKELY_SERVICE_NAMES = [ 'telnet' ]
        PRIVATE_TYPES        = [ :password ]
        REALM_KEY            = nil

        # @!attribute verbosity
        #   The timeout to wait for the telnet banner.
        #
        #   @return [Fixnum]
        attr_accessor :banner_timeout
        # @!attribute verbosity
        #   The timeout to wait for the response from a telnet command.
        #
        #   @return [Fixnum]
        attr_accessor :telnet_timeout

        validates :banner_timeout,
                  presence: true,
                  numericality: {
                      only_integer:             true,
                      greater_than_or_equal_to: 1
                  }

        validates :telnet_timeout,
                  presence: true,
                  numericality: {
                      only_integer:             true,
                      greater_than_or_equal_to: 1
                  }

        # (see {Base#attempt_login})
        def attempt_login(credential)
          result_options = {
              credential: credential
          }

          if connect_reset_safe == :refused
            result_options[:status] = Metasploit::Model::Login::Status::UNABLE_TO_CONNECT
          else
            if busy_message?
              self.sock.close unless self.sock.closed?
              result_options[:status] = Metasploit::Model::Login::Status::UNABLE_TO_CONNECT
            end
          end

          unless result_options[:status]
            unless password_prompt?
              send_user(credential.public)
            end

            recvd_sample = @recvd.dup
            # Allow for slow echos
            1.upto(10) do
              recv_telnet(self.sock, 0.10) unless @recvd.nil? or @recvd[/#{@password_prompt}/]
            end

            if password_prompt?(credential.public)
              send_pass(credential.private)

              # Allow for slow echos
              1.upto(10) do
                recv_telnet(self.sock, 0.10) if @recvd == recvd_sample
              end
            end

            if login_succeeded?
              result_options[:status] = Metasploit::Model::Login::Status::SUCCESSFUL
            else
              result_options[:status] = Metasploit::Model::Login::Status::INCORRECT
            end

          end

          ::Metasploit::Framework::LoginScanner::Result.new(result_options)
        end

        private

        # This method sets the sane defaults for things
        # like timeouts and TCP evasion options
        def set_sane_defaults
          self.connection_timeout ||= 30
          self.max_send_size      ||= 0
          self.port               ||= DEFAULT_PORT
          self.send_delay         ||= 0
          self.banner_timeout     ||= 25
          self.telnet_timeout     ||= 10
          self.connection_timeout ||= 30
          # Shim to set up the ivars from the old Login mixin
          create_login_ivars
        end

      end
    end
  end
end