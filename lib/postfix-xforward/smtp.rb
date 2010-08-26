require 'postfix-xforward/version'
require 'postfix-xforward/utils'
  
module PostfixXForward
  module SMTP

    # RFC 822: maximum SMTP command line length is 512 (including <CRLF>)
    # This is set to the maximum length, NOT including the <CRLF>
    MAXLEN = 510

    # Official XFORWARD command extension name
    XCMD = 'XFORWARD'

    # Extend Net::SMTP to support XFORWARD
    def self.included(base)
      base.class_eval do
        extend ClassMethods
        alias_method :initialize_without_xforward, :initialize
        alias_method :initialize,                  :initialize_with_xforward
        alias_method :do_start_without_xforward,   :do_start
        alias_method :do_start,                    :do_start_with_xforward
        alias_method :do_finish_without_xforward,  :do_finish
        alias_method :do_finish,                   :do_finish_with_xforward
      end
      class << base
        alias_method :start_without_xforward, :start
        alias_method :start,                  :start_with_xforward
      end
    end

    module ClassMethods
      # - Aliased as #start
      # - Original #start available as #start_without_xforward
      #
      # This version adds an optional xforward_attrs parameter to the end of the
      # list. You may provide a hash for this parameter to specify any XFORWARD
      # attribute values you wish to provide the SMTP server on the other end.
      #
      # If the server doesn't support XFORWARD, then XFORWARD won't be
      # attempted. Each of the provided XFORWARD attributes aren't supported by
      # the server won't be transmitted either. So, for an attribute to be
      # successfully transmitted via XFORWARD, the server must support the
      # XFORWARD attribute specifically (and XFORWARD generally).
      #
      # Currently, Postfix documents the following XFORWARD attributes
      # (from http://www.postfix.com/XFORWARD_README.html):
      #
      # NAME::   The up-stream hostname
      # ADDR::   The up-stream network address
      # PORT::   The up-stream client TCP port number
      # PROTO::  Protocol used for receiving mail from the up-stream host
      # HELO::   Hostname that the up-stream announced itself with
      # IDENT::  Local message identifier on the up-stream host
      # SOURCE:: Either "LOCAL" or "REMOTE" : where the up-stream host received
      #          the message from
      def start_with_xforward(address,
          port           = nil,
          helo           = 'localhost.localdomain',
          user           = nil,
          secret         = nil,
          authtype       = nil,
          xforward_attrs = nil,
          &block
        )
        new(address, port, xforward_attrs).start(helo, user, secret, authtype, &block)
      end

      # This method accomplishes the same thing as our overridden version of
      # the #start class method above (#start_with_xforward) but re-orders the
      # parameters, giving priority (and making required) the xforward_attrs
      # hash. Also the server address and port are now combined in one string
      # that should use 'domain.tld:10025' syntax to explicitely define a port.
      def xstart(address_and_port, xforward_attrs,
          helo           = 'localhost.localdomain',
          user           = nil,
          secret         = nil,
          authtype       = nil,
          &block
        )
        address = address_and_port
        port    = 25
        if address_and_port =~ /^(.+):(\d+)$/
          address = $1
          port    = $2.to_i
        end
        new(address, port, xforward_attrs).start(helo, user, secret, authtype, &block)
      end
    end

    # - Aliased as #initialize
    # - Original #initialize available as #initialize_without_xforward
    # This extended version of #initialize allows us to receive an optional
    # Hash of XFORWARD attributes as the final parameter.
    def initialize_with_xforward(address, port = nil, xforward_attrs = nil)
      initialize_without_xforward(address, port)
      @xforward       = false
      @xforward_attrs = {}
      if xforward_attrs.is_a?(Hash)
        @xforward = true
        # Normalize all provided XFORWARD attribute names to upper case
        # TODO: explicit validation of attributes
        xforward_attrs.each do |k, v|
          @xforward_attrs[k.upcase] = v
        end
      end
    end

    # Query whether to try to use XFORWARD or not.
    def xforward ; @xforward ; end
    # Set whether to try to use XFORWARD or not. This should be done before
    # calling #start. Note that if #start is called in XFORWARD mode but the
    # server doesn't support XFORWARD then it won't by tried anyway.
    def xforward=(bool)
      if @started
        logging('ignoring request to enable/disable use of XFORWARD: SMTP session already started')
        return
      end
      @xforward = bool
    end
  
    # The following attribute accessors allow you to set or query the various
    # XFORWARD attributes that will be sent when the SMTP session is started,
    # so long as the attribute (and XFORWARD in general) is supported by the
    # server. Note that setting an attribute to a non-nil value will
    # automatically set #xforward to true (requesting the use of XFORWARD).
    def xforward_name ; @xforward_attrs['NAME'] ; end
    def xforward_name=(name)
      @xforward = true
      @xforward_attrs['NAME'] = name
    end
    def xforward_addr ; @xforward_attrs['ADDR'] ; end
    def xforward_addr=(addr)
      @xforward = true
      @xforward_attrs['ADDR'] = addr
    end
    def xforward_port ; @xforward_attrs['PORT'] ; end
    def xforward_port=(port)
      @xforward = true
      @xforward_attrs['PORT'] = port
    end
    def xforward_proto ; @xforward_attrs['PROTO'] ; end
    def xforward_proto=(proto)
      @xforward = true
      @xforward_attrs['PROTO'] = proto
    end
    def xforward_helo ; @xforward_attrs['HELO'] ; end
    def xforward_helo=(helo)
      @xforward = true
      @xforward_attrs['HELO'] = helo
    end
    def xforward_ident ; @xforward_attrs['IDENT'] ; end
    def xforward_ident=(ident)
      @xforward = true
      @xforward_attrs['IDENT'] = ident
    end
    def xforward_source ; @xforward_attrs['SOURCE'] ; end
    def xforward_source=(source)
      @xforward = true
      @xforward_attrs['SOURCE'] = source
    end
  
    # true if server advertises XFORWARD.
    # You cannot get a valid value before opening an SMTP session.
    def capable_xforward?
      capapble?(XCMD)
    end
  
    # true if server advertises XFORWARD attribute NAME.
    # You cannot get a valid value before opening an SMTP session.
    def capable_xforward_name?
      xforward_capable?('NAME')
    end
  
    # true if server advertises XFORWARD attribute ADDR.
    # You cannot get a valid value before opening an SMTP session.
    def capable_xforward_addr?
      xforward_capable?('ADDR')
    end
  
    # true if server advertises XFORWARD attribute PORT.
    # You cannot get a valid value before opening an SMTP session.
    def capable_xforward_port?
      xforward_capable?('PORT')
    end
  
    # true if server advertises XFORWARD attribute PROTO.
    # You cannot get a valid value before opening an SMTP session.
    def capable_xforward_proto?
      xforward_capable?('PROTO')
    end
  
    # true if server advertises XFORWARD attribute HELO.
    # You cannot get a valid value before opening an SMTP session.
    def capable_xforward_helo?
      xforward_capable?('HELO')
    end
  
    # true if server advertises XFORWARD attribute IDENT.
    # You cannot get a valid value before opening an SMTP session.
    def capable_xforward_ident?
      xforward_capable?('IDENT')
    end
  
    # true if server advertises XFORWARD attribute SOURCE.
    # You cannot get a valid value before opening an SMTP session.
    def capable_xforward_source?
      xforward_capable?('SOURCE')
    end

    # Returns supported XFORWARD attributes on the SMTP server.
    # You cannot get valid values before opening SMTP session.
    def capable_xforward_attrs
      return [] unless @capabilities
      return [] unless @capabilities[XCMD]
      @capabilities[XCMD]
    end
  
    private
  
    def xforward_capapble?(attr)
      return nil   unless @capabilities
      return false unless @capabilities[XCMD]
      @capabilities[XCMD].include?(attr)
    end

    def do_start_with_xforward(helo_domain, user, secret, authtype)
      do_start_without_xforward(helo_domain, user, secret, authtype)
      if @started and @xforward
        if capable?(XCMD)
          do_xforward
        else
          logging("ignoring request to do XFORWARD: server isn't capable")
        end
      end
    end

    def do_finish_with_xforward
      do_finish_without_xforward
      @xforward = false
      @xforward_attrs = {}
    end

    # Issues the XFORWARD smtp command, sending each of the supplied
    # XFORWARD attributes (as long as they are supported). Unsupported
    # XFORWARD attributes are ignored.
    def do_xforward
      cmd = XCMD.dup
      cap = capable_xforward_attrs
      @xforward_attrs.each do |attr, value|
        if cap.include?(attr)
          attr = '[UNAVAILABLE]' if value.nil? or value.empty?
          tmp = " #{attr}=#{Utils.xtext(value)}"
          if cmd.length + tmp.length > MAXLEN
            getok(cmd)
            cmd = XCMD.dup
          end
          cmd << tmp
        else
          logging("ignoring XFORWARD attribute '#{attr}': unsupported by server")
        end
      end
      getok(cmd) if cmd != XCMD
    end

  end
end
