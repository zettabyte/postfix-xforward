require 'net/smtp'
module PostfixXForward
  class << self
    # hooks PostfixXForward::SMTP into Net::SMTP
    def enable
      return if Net::SMTP.respond_to? :xstart
      require 'postfix-xforward/smtp'
      Net::SMTP.send :include, SMTP
    end
  end
end
PostfixXForward.enable
