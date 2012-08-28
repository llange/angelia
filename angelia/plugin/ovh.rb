require 'soap/wsdlDriver'

module Angelia::Plugin
    # Plugin that sends SMS messages via OVH SMS SoAPI
    # Product: http://www.ovh.fr/sms_et_fax/
    # API : http://www.ovh.com/soapi/en/
    #
    # plugin = Ovh
    # plugin.Ovh.login = xxx        # the sms user login (It's better to create a specific account to send SMS)
    # plugin.Ovh.password = yyyyy   # the sms user password
    # plugin.Ovh.smsaccount = 123   # the SMS account (generally in the form sms-<your user account>-X)
    # plugin.Ovh.numberfrom = 123   # the number from (text or numbers. Must be pre-declared in the backoffice)
    # plugin.Ovh.smsvalidity = 10   # the maximum time -in minute(s)- before the message is dropped, defaut is 10 minutes
    # plugin.Ovh.smsclass = 1       # the sms class: flash(0),phone display(1),SIM(2),toolkit(3), default is 1
    # plugin.Ovh.smsdeferred = 0    # the time -in minute(s)- to wait before sending the message, default is 0
    # plugin.Ovh.smspriority = 3    # the priority of the message (0 to 3), default is 3
    # plugin.Ovh.smscoding = 1      # the sms coding : 1 for 7 bit or 2 for unicode, default is 1
    # plugin.Ovh.tag = angelia      # an optional tag
    # plugin.Ovh.nostop = true      # do not display STOP clause in the message, this requires that this is not an advertising message
    #
    # You can then send sms to people using ovh://xxxxxxxxxxx or ovh://+xxxxxxxxxxxx (International format with country code first)
    #
    # If there's a submission problem this plugin will wait 2 minutes before
    # trying again, just to not be hitting their API too hard
    class Ovh
        def initialize(config)
            Angelia::Util.debug("Creating new insance of Ovh plugin")

            @config = config
            @lastfailure = 0

            # We should have a look at the version number from time to time
            # and see if it is necessary to change this
            wsdl = 'https://www.ovh.com/soapi/soapi-re-1.46.wsdl'
            @soapi = SOAP::WSDLDriverFactory.new(wsdl).create_rpc_driver
        end

        def self.register
            Angelia::Util.register_plugin("ovh", "Ovh")
        end

        def send(recipient, subject, msg)
            if recipient.match(/^\+/).nil?
                recipient = "+" + recipient
            end
            Angelia::Util.debug("#{self.class} Sending message to '#{recipient}' with subject '#{subject}' and body '#{msg}'")

            login = @config["login"]
            password = @config["password"]
            smsaccount = @config["smsaccount"]
            numberfrom = @config["numberfrom"]
            smsvalidity = @config["smsvalidity"]
            smsclass = @config["smsclass"]
            smsdeferred = @config["smsdeferred"]
            smspriority = @config["smspriority"]
            smscoding = @config["smscoding"]

            # Default values
            smspriority ||= 3
            smsdeferred ||= 0
            smsclass ||= 1
            smsvalidity ||= 10
            smscoding ||= 1
            tag = @config["tag"]
            nostop = true if (not @config["nostop"].nil?) and (@config["nostop"].downcase == "true")

            # if we had a failed delivery in the last 10 minutes do not try to send a new message
            if Time.now.to_i - @lastfailure.to_i > 120
                begin
                    res = @soapi.telephonySmsUserSend(login, password, smsaccount, numberfrom, recipient, msg, smsvalidity, smsclass, smsdeferred, smspriority, smscoding, tag, nostop)
                    @lastfailure = 0

                rescue ::Clickatell::API::Error => e
                    @lastfailure = Time.now
                    raise "Unable to send message: #{e}"

                rescue Exception => e
                    @lastfailure = Time.now
                    raise(Angelia::PluginConnectionError, "Unhandled issue sending alert: #{e}")
                end
            else
                raise(Angelia::PluginConnectionError, "Not delivering message, we've had failures in the last 2 mins")
            end
        end
    end
end

# vi:tabstop=4:expandtab:ai
