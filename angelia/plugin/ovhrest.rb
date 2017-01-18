require 'ovh/rest'

module Angelia::Plugin
    # Plugin that sends SMS messages via OVH SMS REST API
    # Product: https://www.ovhtelecom.fr/sms/
    # API : https://api.ovh.com/g934.first_step_with_api https://eu.api.ovh.com/console/#/sms
    #
    # plugin = OvhRest
    #     # Authentication consists of two keys. The first is the application key. 
    #     # Any application wanting to communicate with the OVH API must be declared in advance.
    #     # the application key, named AK
    # plugin.OvhRest.application_key = xxxxxxxxxxxxxxxxx # the application key, named AK. (MANDATORY)
    # plugin.OvhRest.application_secret = xxxxxxxxxxxxxx # your secret application key, named AS. (MANDATORY)
    # plugin.OvhRest.consumer_key = xxxxxxxxxxxxxxxxxxxx # consumerKey (the token, named CK). (MANDATORY)
    # plugin.OvhRest.smsaccount = xxxxxxxxxxxxxx         # the SMS account (generally in the form sms-<your user account>-X). (MANDATORY)
    # plugin.OvhRest.smsclass = phoneDisplay             # the sms class: flash,phoneDisplay,sim,toolkit. default is phoneDisplay. (optional)
    # plugin.OvhRest.smscoding = 7bit                    # the sms coding : 7bit or 8bit, the default is 7bit. (optional)
    # plugin.OvhRest.smsdeferred = 0                     # the time -in minute(s)- to wait before sending the message, default is 0. (optional)
    # plugin.OvhRest.nostop = true                       # do not display STOP clause in the message, this requires that this is not an advertising message. (optional)
    # plugin.OvhRest.smspriority = high                  # the priority of the message: high, low, medium, veryLow. Default is high. (optional)
    # plugin.OvhRest.numberfrom = xxxxxxxxxxx            # the number from (text or numbers. Must be pre-declared in the backoffice). (optional)
    # plugin.OvhRest.sender_for_response = false         # flag (true/false) to allow for a response. Not compatible with numberfrom. Default is false. (optional)
    # plugin.OvhRest.tag = angelia                       # an optional tag. (optional)
    # plugin.OvhRest.smsvalidity = 10                    # the maximum time -in minute(s)- before the message is dropped, defaut is 10 minutes. (optional)
    #
    # You can then send sms to people using ovh://xxxxxxxxxxx or ovh://+xxxxxxxxxxxx (International format with country code first)
    #
    # If there's a submission problem this plugin will wait 2 minutes before
    # trying again, just to not be hitting their API too hard
    class OvhRest
        def initialize(config)
            Angelia::Util.debug("Creating new insance of Ovh Rest plugin")

            @config = config
            @lastfailure = 0

            application_key = @config["application_key"]
            application_secret = @config["application_secret"]
            consumer_key = @config["consumer_key"]
            @ovh_rest_api = OVH::REST.new(application_key, application_secret, consumer_key)
        end

        def self.register
            Angelia::Util.register_plugin("ovh", "OvhRest")
        end

        def send(recipient, subject, msg)
            if recipient.match(/^\+/).nil?
                recipient = "+" + recipient
            end
            Angelia::Util.debug("#{self.class} Sending message to '#{recipient}' with subject '#{subject}' and body '#{msg}'")

            smsaccount = @config["smsaccount"]
            numberfrom = @config["numberfrom"]
            smsvalidity = @config["smsvalidity"]
            smsclass = @config["smsclass"]
            smsdeferred = @config["smsdeferred"]
            smspriority = @config["smspriority"]
            smscoding = @config["smscoding"]
            tag = @config["tag"]

            # Default values
            smsclass ||= 'phoneDisplay'
            smscoding ||= '7bit'
            smsdeferred ||= 0
            nostop = false
            nostop = true if (not @config["nostop"].nil?) and (@config["nostop"].downcase == "true")
            smspriority ||= 'high'
            numberfrom ||= ''
            sender_for_response = false
            sender_for_response = true if (not @config["sender_for_response"].nil?) and (@config["sender_for_response"].downcase == "true")
            tag ||= ''
            smsvalidity ||= 10

            # if we had a failed delivery in the last 2 minutes do not try to send a new message
            if Time.now.to_i - @lastfailure.to_i > 120
                begin
                    Angelia::Util.debug("#{self.class} Before sending")
                    result = @ovh_rest_api.post("/sms/#{smsaccount}/jobs", {
                      "charset" => "UTF-8",
                      "class" => smsclass,
                      "coding" => smscoding,
                      "differedPeriod" => smsdeferred,
                      "message" => msg,
                      "noStopClause" => nostop,
                      "priority" => smspriority,
                      "receivers" => [recipient],
                      "sender" => numberfrom,
                      "senderForResponse" => sender_for_response,
                      "tag" => tag,
                      "validityPeriod" => smsvalidity,
                    })
                    @lastfailure = 0

                rescue OVH::RESTError => e
                    Angelia::Util.debug("#{self.class} OVH::RESTError")
                    @lastfailure = Time.now
                    raise "Unable to send message: #{e}"

                rescue Exception => e
                    Angelia::Util.debug("#{self.class} other Exception")
                    @lastfailure = Time.now
                    raise(Angelia::PluginConnectionError, "Unhandled issue sending alert: #{e}")
                end
            else
                Angelia::Util.debug("#{self.class} Not delivering message, we've had failures in the last 2 mins")
                raise(Angelia::PluginConnectionError, "Not delivering message, we've had failures in the last 2 mins")
            end
        end
    end
end

# vi:tabstop=4:expandtab:ai
