# frozen_string_literal: true

module SignalWire
  module POM
    # Represents a section in the Prompt Object Model.
    #
    # Each section contains a title, optional body text, optional bullet
    # points, and can have any number of nested subsections.
    #
    # Mirrors Python's ``signalwire.pom.pom.Section`` exactly. See
    # ``signalwire-python/signalwire/signalwire/pom/pom.py`` for the
    # source-of-truth specification; rendering output (markdown / XML /
    # JSON / YAML) must match Python byte-for-byte so cross-language POM
    # documents are interoperable.
    #
    # Attributes:
    # * +title+ — the name of the section.
    # * +body+  — a paragraph of text associated with the section.
    # * +bullets+ — bullet-pointed items (Array<String>).
    # * +subsections+ — nested Section objects.
    # * +numbered+ — whether this section should be numbered.
    # * +numbered_bullets+ — whether bullets should be numbered (rendered
    #   to/from the JSON/YAML key +numberedBullets+ for Python parity).
    class Section
      attr_accessor :title, :body, :bullets, :subsections, :numbered, :numbered_bullets

      # Construct a Section.
      #
      # All arguments after +title+ are keyword arguments mirroring the
      # Python ``Section.__init__`` signature. ``numbered_bullets`` is
      # snake_case in Ruby; the camelCase ``numberedBullets`` form used
      # by Python's JSON/YAML serialization is preserved on the wire.
      def initialize(title = nil, body: '', bullets: nil, numbered: nil, numbered_bullets: false)
        validate_body!(body)
        validate_bullets!(bullets)

        @title = title
        @body = body
        @bullets = bullets || []
        @subsections = []
        @numbered = numbered
        @numbered_bullets = numbered_bullets
      end

      # Add or replace the body text for this section. Mirrors Python's
      # ``Section.add_body`` (which is documented to "Add or replace").
      def add_body(body)
        raise TypeError, "body must be a string, not #{body.class.name}" unless body.is_a?(String)

        @body = body
      end

      # Append bullet points to this section. Does not replace existing
      # bullets — mirrors Python's ``self.bullets.extend(bullets)``.
      def add_bullets(bullets)
        raise TypeError, "bullets must be an Array, not #{bullets.class.name}" unless bullets.is_a?(Array)

        @bullets.concat(bullets)
      end

      # Add a subsection to this section, returning the new Section.
      #
      # Raises ArgumentError when +title+ is nil (Python raises
      # ``ValueError("Subsections must have a title")``; Ruby idiom
      # is ArgumentError for invalid arguments).
      def add_subsection(title, body: '', bullets: nil, numbered: false, numbered_bullets: false)
        raise ArgumentError, 'Subsections must have a title' if title.nil?

        sub = Section.new(title, body: body, bullets: bullets || [],
                                 numbered: numbered, numbered_bullets: numbered_bullets)
        @subsections << sub
        sub
      end

      # Convert the section to a Hash representation suitable for JSON or
      # YAML serialization. Keys are emitted in the same order as Python
      # so cross-port string comparisons line up.
      # rubocop:disable Metrics/CyclomaticComplexity -- wire-critical: each guard
      # emits one key in exact Python order; flattening to one branch per field is
      # the clearest expression and must not be split (key order is the contract).
      def to_h
        data = {}
        data['title'] = @title unless @title.nil?
        data['body'] = @body if present?(@body)
        data['bullets'] = @bullets if present?(@bullets)
        data['subsections'] = @subsections.map(&:to_h) if present?(@subsections)
        data['numbered'] = @numbered if @numbered
        data['numberedBullets'] = @numbered_bullets if @numbered_bullets
        data
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      # Render this section and all its subsections as Markdown. The
      # output is byte-for-byte identical to Python's
      # ``Section.render_markdown``.
      def render_markdown(level: 2, section_number: nil)
        md = []
        section_number = [] if section_number.nil?

        md << "#{'#' * level} #{number_prefix(section_number)}#{@title}\n" unless @title.nil?

        md << "#{@body}\n" if present?(@body)

        @bullets.each_with_index do |bullet, idx|
          md << (@numbered_bullets ? "#{idx + 1}. #{bullet}" : "- #{bullet}")
        end

        md << '' unless @bullets.empty?

        render_markdown_subsections(md, level, section_number)

        md.join("\n")
      end

      # Render this section and all its subsections as XML. Output is
      # byte-for-byte identical to Python's ``Section.render_xml``.
      def render_xml(indent: 0, section_number: nil)
        indent_str = '  ' * indent
        xml = []
        section_number = [] if section_number.nil?

        xml << "#{indent_str}<section>"

        xml << "#{indent_str}  <title>#{number_prefix(section_number)}#{@title}</title>" unless @title.nil?

        xml << "#{indent_str}  <body>#{@body}</body>" if present?(@body)

        render_xml_bullets(xml, indent_str) if present?(@bullets)
        render_xml_subsections(xml, indent_str, indent, section_number) if present?(@subsections)

        xml << "#{indent_str}</section>"
        xml.join("\n")
      end

      private

      def validate_body!(body)
        return if body.is_a?(String)

        raise TypeError,
              "body must be a string, not #{body.class.name}. " \
              'If you meant to pass a list of bullet points, use bullets parameter instead.'
      end

      def validate_bullets!(bullets)
        return if bullets.nil? || bullets.is_a?(Array)

        raise TypeError, "bullets must be an Array or nil, not #{bullets.class.name}"
      end

      # True when the value is non-nil and non-empty (string or array).
      def present?(value)
        value && !value.empty?
      end

      # The "N.N. " prefix when this section is numbered, else "".
      def number_prefix(section_number)
        return '' if section_number.empty?

        "#{section_number.join('.')}. "
      end

      # Subsections only inherit/extend numbering when this section is itself
      # titled or already numbered. Mirrors Python's render guard exactly.
      def titled_or_numbered?(section_number)
        !@title.nil? || !section_number.empty?
      end

      def child_section_number(section_number, subsection, idx, any_subsection_numbered)
        if any_subsection_numbered && subsection.numbered != false
          section_number + [idx + 1]
        else
          section_number
        end
      end

      def render_markdown_subsections(lines, level, section_number)
        any_subsection_numbered = @subsections.any?(&:numbered)
        nested = titled_or_numbered?(section_number)
        next_level = nested ? level + 1 : level

        @subsections.each_with_index do |subsection, idx|
          new_section_number =
            nested ? child_section_number(section_number, subsection, idx, any_subsection_numbered) : section_number
          lines << subsection.render_markdown(level: next_level, section_number: new_section_number)
        end
      end

      def render_xml_bullets(xml, indent_str)
        xml << "#{indent_str}  <bullets>"
        @bullets.each_with_index do |bullet, idx|
          xml << if @numbered_bullets
                   "#{indent_str}    <bullet id=\"#{idx + 1}\">#{bullet}</bullet>"
                 else
                   "#{indent_str}    <bullet>#{bullet}</bullet>"
                 end
        end
        xml << "#{indent_str}  </bullets>"
      end

      def render_xml_subsections(xml, indent_str, indent, section_number)
        xml << "#{indent_str}  <subsections>"
        any_subsection_numbered = @subsections.any?(&:numbered)
        nested = titled_or_numbered?(section_number)

        @subsections.each_with_index do |subsection, idx|
          new_section_number =
            nested ? child_section_number(section_number, subsection, idx, any_subsection_numbered) : section_number
          xml << subsection.render_xml(indent: indent + 2, section_number: new_section_number)
        end
        xml << "#{indent_str}  </subsections>"
      end
    end
  end
end
