module PostfixXForward
  class Utils
    # Convert the txt string to "xtext" as defined in RFC 1891
    def Utils.xtext(txt)
      txt.gsub(/[+=\x00-\x20\x7f-\xff]/) do |c|
        "+#{c.unpack('H2').first.upcase}"
      end
    end
  end
end
