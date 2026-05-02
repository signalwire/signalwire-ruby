# frozen_string_literal: true

require 'json'
require 'yaml'

require_relative 'section'

module SignalWire
  module POM
    # A structured data format for composing, organising, and rendering
    # prompt instructions for large language models.
    #
    # The Prompt Object Model provides a tree-based representation of a
    # prompt document composed of nested Section objects, each of which
    # can include a title, body text, bullet points, and arbitrarily
    # nested subsections.
    #
    # Mirrors Python's ``signalwire.pom.pom.PromptObjectModel``. The
    # rendered output (Markdown / XML / JSON / YAML) is byte-for-byte
    # identical to the Python reference so cross-language POM documents
    # interoperate.
    class PromptObjectModel
      attr_accessor :sections, :debug

      def initialize(debug: false)
        @sections = []
        @debug = debug
      end

      # Build a PromptObjectModel from JSON.
      #
      # +json_data+ may be either a JSON string or an already-parsed
      # Array. Mirrors Python's
      # ``PromptObjectModel.from_json(json_data: Union[str, dict])``.
      def self.from_json(json_data)
        data = json_data.is_a?(String) ? JSON.parse(json_data) : json_data
        _from_array(data)
      end

      # Build a PromptObjectModel from YAML.
      #
      # +yaml_data+ may be either a YAML string or an already-parsed
      # Array. Mirrors Python's
      # ``PromptObjectModel.from_yaml(yaml_data: Union[str, dict])``.
      def self.from_yaml(yaml_data)
        data = yaml_data.is_a?(String) ? YAML.safe_load(yaml_data) : yaml_data
        _from_array(data)
      end

      # Internal: build a PromptObjectModel from a raw Array of Hash
      # section descriptors. Mirrors Python's ``_from_dict`` (which
      # confusingly takes a list, not a dict).
      def self._from_array(data)
        pom = new
        data = [] if data.nil?
        unless data.is_a?(Array)
          raise ArgumentError, "POM root must be an Array, got #{data.class.name}"
        end

        data.each_with_index do |sec, idx|
          if idx.positive? && !sec.key?('title')
            sec['title'] = 'Untitled Section'
          end
          pom.sections << _build_section(sec)
        end
        pom
      end

      # Internal: build a Section (recursively) from a Hash section
      # descriptor. Mirrors Python's ``build_section`` inner helper.
      def self._build_section(hash, is_subsection: false)
        unless hash.is_a?(Hash)
          raise ArgumentError, 'Each section must be a Hash.'
        end

        if hash.key?('title') && !hash['title'].is_a?(String)
          raise ArgumentError, "'title' must be a string if present."
        end
        if hash.key?('subsections') && !hash['subsections'].is_a?(Array)
          raise ArgumentError, "'subsections' must be an Array if provided."
        end
        if hash.key?('bullets') && !hash['bullets'].is_a?(Array)
          raise ArgumentError, "'bullets' must be an Array if provided."
        end
        if hash.key?('numbered') && ![true, false].include?(hash['numbered'])
          raise ArgumentError, "'numbered' must be a boolean if provided."
        end
        if hash.key?('numberedBullets') && ![true, false].include?(hash['numberedBullets'])
          raise ArgumentError, "'numberedBullets' must be a boolean if provided."
        end

        has_body = hash.key?('body') && hash['body'] && !hash['body'].empty?
        has_bullets = hash.key?('bullets') && hash['bullets'] && !hash['bullets'].empty?
        has_subsections = hash.key?('subsections') && hash['subsections'] && !hash['subsections'].empty?
        unless has_body || has_bullets || has_subsections
          raise ArgumentError,
                'All sections must have either a non-empty body, non-empty bullets, or subsections'
        end

        if is_subsection && !hash.key?('title')
          raise ArgumentError, 'All subsections must have a title'
        end

        kwargs = {
          body: hash.fetch('body', ''),
          bullets: hash.fetch('bullets', [])
        }
        kwargs[:numbered] = hash['numbered'] if hash.key?('numbered')
        kwargs[:numbered_bullets] = hash['numberedBullets'] if hash.key?('numberedBullets')

        section = Section.new(hash['title'], **kwargs)

        (hash['subsections'] || []).each do |sub|
          section.subsections << _build_section(sub, is_subsection: true)
        end
        section
      end

      # Add a top-level section to the model and return the new Section.
      #
      # Mirrors Python's ``PromptObjectModel.add_section``. If +bullets+
      # is a String it is wrapped into a single-element Array (Python
      # parity). Raises ArgumentError when +title+ is nil and the model
      # already has at least one section (only the first section may
      # be untitled).
      def add_section(title = nil, body: '', bullets: nil, numbered: nil, numbered_bullets: false)
        if title.nil? && !@sections.empty?
          raise ArgumentError, 'Only the first section can have no title'
        end

        bullets_list = bullets.is_a?(String) ? [bullets] : (bullets || [])

        section = Section.new(title, body: body, bullets: bullets_list,
                                     numbered: numbered, numbered_bullets: numbered_bullets)
        @sections << section
        section
      end

      # Find a section by title, recursing into subsections. Returns
      # +nil+ when the title is not present anywhere in the tree.
      def find_section(title)
        recurse = lambda do |sections|
          sections.each do |section|
            return section if section.title == title

            found = recurse.call(section.subsections)
            return found if found
          end
          nil
        end
        recurse.call(@sections)
      end

      # Convert the model to a JSON string. Output matches Python's
      # ``json.dumps(..., indent=2)`` byte-for-byte, with one
      # special case: an empty model serializes to ``"[]"`` (Ruby's
      # default ``JSON.pretty_generate([])`` emits ``"[\n\n]"``).
      def to_json(*_args)
        return '[]' if @sections.empty?

        JSON.pretty_generate(@sections.map(&:to_h))
      end

      # Convert the model to a YAML string. Output matches Python's
      # ``yaml.dump(..., default_flow_style=False, sort_keys=False)``
      # byte-for-byte. Ruby's ``YAML.dump`` prepends ``---\n``; we strip
      # it. The empty-list case (Ruby emits ``--- []\n``) is normalised
      # to Python's ``[]\n``.
      def to_yaml
        return "[]\n" if @sections.empty?

        yaml = YAML.dump(@sections.map(&:to_h))
        yaml.sub(/\A---\s*\n/, '')
      end

      # Convert the model to an Array of Hash section descriptors.
      # Mirrors Python's ``PromptObjectModel.to_dict`` (Ruby idiom uses
      # ``to_h``).
      def to_h
        @sections.map(&:to_h)
      end

      # Render the entire model as Markdown. Output is byte-for-byte
      # identical to Python's ``PromptObjectModel.render_markdown``.
      def render_markdown
        any_section_numbered = @sections.any? { |s| s.numbered }

        if @debug
          warn "Any section numbered: #{any_section_numbered}"
          @sections.each_with_index do |section, idx|
            warn "Section #{idx + 1}: #{section.title}, numbered=#{section.numbered}"
          end
        end

        md = []
        section_counter = 0
        @sections.each_with_index do |section, idx|
          if !section.title.nil?
            section_counter += 1
            section_number =
              if any_section_numbered && section.numbered != false
                [section_counter]
              else
                []
              end
          else
            section_number = []
          end

          if @debug
            warn "Rendering section #{idx}: #{section.title} with section_number=#{section_number.inspect}"
          end

          md << section.render_markdown(section_number: section_number)
        end

        md.join("\n")
      end

      # Render the entire model as XML. Output is byte-for-byte identical
      # to Python's ``PromptObjectModel.render_xml``.
      def render_xml
        xml = ['<?xml version="1.0" encoding="UTF-8"?>', '<prompt>']
        any_section_numbered = @sections.any? { |s| s.numbered }

        section_counter = 0
        @sections.each do |section|
          if !section.title.nil?
            section_counter += 1
            section_number =
              if any_section_numbered && section.numbered != false
                [section_counter]
              else
                []
              end
          else
            section_number = []
          end

          xml << section.render_xml(indent: 1, section_number: section_number)
        end

        xml << '</prompt>'
        xml.join("\n")
      end

      # Add another PromptObjectModel as a subsection of an existing
      # section identified either by title or by Section reference.
      #
      # Mirrors Python's
      # ``PromptObjectModel.add_pom_as_subsection(target, pom_to_add)``.
      def add_pom_as_subsection(target, pom_to_add)
        case target
        when String
          target_section = find_section(target)
          raise ArgumentError, "No section with title '#{target}' found." if target_section.nil?
        when Section
          target_section = target
        else
          raise TypeError, 'Target must be a String or a Section object.'
        end

        pom_to_add.sections.each do |section|
          target_section.subsections << section
        end
      end
    end
  end
end
