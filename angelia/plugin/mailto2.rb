require 'rubygems'
require 'tmail'
require 'net/smtp'

module Angelia::Plugin

    # A simple mailto plugin for sending email from nagios in a way
    # that is more maintainable/configurable than the nagios default
    # of 'printf | mail'
    # Copied from plugin 'Mailto' and modified to use 'tmail' instead
    class Mailto2
        def initialize(config)
            Angelia::Util.debug("Creating new instance of Mailto plugin")

            @config = config
        end

        def self.register
            Angelia::Util.register_plugin("mailto", "Mailto2")
        end

        def send(recipient, subject, msg)
            Angelia::Util.debug("#{self.class} Sending message to '#{recipient}' with subject '#{subject}' and body '#{msg}'")

            begin
                mail = TMail::Mail.parse(msg)
                Angelia::Util.debug("#{self.class} message parsed ok")
            rescue StandardError => exception
                mail = TMail::Mail.new
                Angelia::Util.debug("#{self.class} message not parsed ok, error #{exception}")
            end

            Angelia::Util.debug("#{self.class} Before: from '#{mail.from}'")
            Angelia::Util.debug("#{self.class} Before: to '#{mail.to}'")
            Angelia::Util.debug("#{self.class} Before: subject '#{mail.subject}'")

            # Assume some defaults if not specified in the template.
            mail.to ||= recipient
            mail.subject ||= subject
            # TODO(sissel): would be nice to expose the config to the template
            # so we could set this there.
            mail.from ||= @config["from"]

            # If the mail doesn't parse, we probably won't have a body,
            # so let's assume the 'msg' is the body.
            if mail.body == ""
                mail.body = msg
            end
            Angelia::Util.debug("#{self.class} After: from '#{mail.from}'")
            Angelia::Util.debug("#{self.class} After: to '#{mail.to}'")
            Angelia::Util.debug("#{self.class} After: subject '#{mail.subject}'")
#            Angelia::Util.debug("#{self.class} body '#{mail.body}'")

            Angelia::Util.debug("Mail contents:\n#{mail.to_s}")

            Net::SMTP.start( ( @config["server"] || "localhost" ), ( @config["port"]   || 25 ) ) do |smtp|
                smtp.send_message(
                   mail.to_s,
                   mail.from,
                   mail.to
                )
                smtp.finish
            end
        end
    end
end

# vi:shiftwidth=4:tabstop=4:expandtab:ai
