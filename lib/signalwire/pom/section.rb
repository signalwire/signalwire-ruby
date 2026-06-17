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
        @title = title

        unless body.is_a?(String)
          raise TypeError,
                "body must be a string, not #{body.class.name}. " \
                'If you meant to pass a list of bullet points, use bullets parameter instead.'
        end
        @body = body

        if !bullets.nil? && !bullets.is_a?(Array)
          raise TypeError, "bullets must be an Array or nil, not #{bullets.class.name}"
        end

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
      def to_h
        data = {}
        data['title'] = @title unless @title.nil?
        data['body'] = @body if @body && !@body.empty?
        data['bullets'] = @bullets if @bullets && !@bullets.empty?
        data['subsections'] = @subsections.map(&:to_h) if @subsections && !@subsections.empty?
        data['numbered'] = @numbered if @numbered
        data['numberedBullets'] = @numbered_bullets if @numbered_bullets
        data
      end

      # Render this section and all its subsections as Markdown. The
      # output is byte-for-byte identical to Python's
      # ``Section.render_markdown``.
      def render_markdown(level: 2, section_number: nil)
        md = []
        section_number = [] if section_number.nil?

        unless @title.nil?
          prefix = ''
          prefix = "#{section_number.join('.')}. " unless section_number.empty?
          md << "#{'#' * level} #{prefix}#{@title}\n"
        end

        md << "#{@body}\n" if @body && !@body.empty?

        @bullets.each_with_index do |bullet, idx|
          md << if @numbered_bullets
                  "#{idx + 1}. #{bullet}"
                else
                  "- #{bullet}"
                end
        end

        md << '' unless @bullets.empty?

        any_subsection_numbered = @subsections.any? { |sub| sub.numbered }

        @subsections.each_with_index do |subsection, idx|
          if !@title.nil? || !section_number.empty?
            new_section_number =
              if any_subsection_numbered && subsection.numbered != false
                section_number + [idx + 1]
              else
                section_number
              end
            next_level = level + 1
          else
            new_section_number = section_number
            next_level = level
          end

          md << subsection.render_markdown(level: next_level, section_number: new_section_number)
        end

        md.join("\n")
      end

      # Render this section and all its subsections as XML. Output is
      # byte-for-byte identical to Python's ``Section.render_xml``.
      def render_xml(indent: 0, section_number: nil)
        indent_str = '  ' * indent
        xml = []
        section_number = [] if section_number.nil?

        xml << "#{indent_str}<section>"

        unless @title.nil?
          prefix = ''
          prefix = "#{section_number.join('.')}. " unless section_number.empty?
          xml << "#{indent_str}  <title>#{prefix}#{@title}</title>"
        end

        xml << "#{indent_str}  <body>#{@body}</body>" if @body && !@body.empty?

        if @bullets && !@bullets.empty?
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

        if @subsections && !@subsections.empty?
          xml << "#{indent_str}  <subsections>"
          any_subsection_numbered = @subsections.any? { |sub| sub.numbered }

          @subsections.each_with_index do |subsection, idx|
            new_section_number = if !@title.nil? || !section_number.empty?
                                   if any_subsection_numbered && subsection.numbered != false
                                     section_number + [idx + 1]
                                   else
                                     section_number
                                   end
                                 else
                                   section_number
                                 end
            xml << subsection.render_xml(indent: indent + 2, section_number: new_section_number)
          end
          xml << "#{indent_str}  </subsections>"
        end

        xml << "#{indent_str}</section>"
        xml.join("\n")
      end
    end
  end
end
