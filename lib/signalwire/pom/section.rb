# frozen_string_literal: true

module SignalWire
  # POM — the Prompt Object Model: structured prompt sections rendered to markdown.
  module POM
    # Represents a section in the Prompt Object Model.
    #
    # Each section contains a title, optional body text, optional bullet
    # points, and can have any number of nested subsections.
    #
    # The rendering output (markdown / XML / JSON / YAML) is part of the POM
    # contract: key order and formatting are load-bearing, so a document
    # written by this SDK is byte-comparable with one written by any other
    # POM producer. Treat the renderers as wire code, not cosmetics.
    #
    # Attributes:
    # * +title+ — the name of the section.
    # * +body+  — a paragraph of text associated with the section.
    # * +bullets+ — bullet-pointed items (Array<String>).
    # * +subsections+ — nested Section objects.
    # * +numbered+ — whether this section should be numbered.
    # * +numbered_bullets+ — whether bullets should be numbered (rendered
    #   to/from the JSON/YAML key +numberedBullets+).
    class Section
      attr_accessor :title, :body, :bullets, :subsections, :numbered, :numbered_bullets

      # Construct a Section.
      #
      # +title+ is positional; every argument after it is a keyword.
      # ``numbered_bullets`` is snake_case in the Ruby API but serializes to
      # the camelCase ``numberedBullets`` key on the wire.
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

      # Add or replace the body text for this section — an existing body is
      # overwritten, not appended to.
      def add_body(body)
        raise TypeError, "body must be a string, not #{body.class.name}" unless body.is_a?(String)

        @body = body
      end

      # Append bullet points to this section. Does not replace existing
      # bullets — the given Array is concatenated onto them.
      def add_bullets(bullets)
        raise TypeError, "bullets must be an Array, not #{bullets.class.name}" unless bullets.is_a?(Array)

        @bullets.concat(bullets)
      end

      # Add a subsection to this section, returning the new Section.
      #
      # A subsection MUST have a title: +title+ of nil raises ArgumentError
      # ("Subsections must have a title"), the Ruby idiom for an invalid
      # argument.
      def add_subsection(title, body: '', bullets: nil, numbered: false, numbered_bullets: false)
        raise ArgumentError, 'Subsections must have a title' if title.nil?

        sub = Section.new(title, body: body, bullets: bullets || [],
                                 numbered: numbered, numbered_bullets: numbered_bullets)
        @subsections << sub
        sub
      end

      # Convert the section to a Hash representation suitable for JSON or
      # YAML serialization. Key emission order is fixed: title, body, bullets,
      # subsections, numbered, numberedBullets.
      # rubocop:disable Metrics/CyclomaticComplexity -- wire-critical: each guard
      # emits one key in that exact order; flattening to one branch per field is
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

      # Render this section and all its subsections as Markdown. The exact
      # output is part of the POM contract — see the class docs.
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

      # Render this section and all its subsections as XML. The exact output
      # is part of the POM contract — see the class docs.
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

      # @api private — a body must be a String. The error explicitly points at the
      # `bullets:` parameter, because passing a list here is the common mistake.
      #
      # @raise [TypeError]
      def validate_body!(body)
        return if body.is_a?(String)

        raise TypeError,
              "body must be a string, not #{body.class.name}. " \
              'If you meant to pass a list of bullet points, use bullets parameter instead.'
      end

      # @api private — bullets must be an Array or nil.
      #
      # @raise [TypeError]
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
      # titled or already numbered.
      def titled_or_numbered?(section_number)
        !@title.nil? || !section_number.empty?
      end

      # @api private — the number a subsection renders under: the parent's number
      # extended by its position when this level is numbered, else the parent's
      # number unchanged. A subsection with `numbered: false` opts out.
      #
      # @return [Array<Integer>]
      def child_section_number(section_number, subsection, idx, any_subsection_numbered)
        if any_subsection_numbered && subsection.numbered != false
          section_number + [idx + 1]
        else
          section_number
        end
      end

      # @api private — render each subsection as markdown. The heading level only
      # deepens when this section is itself titled or numbered, so an untitled
      # wrapper does not push its children a level down.
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

      # @api private — render the bullets as a `<bullets>` element. Numbered bullets
      # carry a 1-based `id` attribute.
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

      # @api private — render each subsection inside a `<subsections>` element,
      # computing each child's number the same way the markdown renderer does.
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
