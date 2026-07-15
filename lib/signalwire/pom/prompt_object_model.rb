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
        raise ArgumentError, "POM root must be an Array, got #{data.class.name}" unless data.is_a?(Array)

        data.each_with_index do |sec, idx|
          sec['title'] = 'Untitled Section' if idx.positive? && !sec.key?('title')
          pom.sections << SectionBuilder.build(sec)
        end
        pom
      end

      # Add a top-level section to the model and return the new Section.
      #
      # If +bullets+ is a String it is wrapped into a single-element Array.
      # Raises ArgumentError when +title+ is nil and the model already has
      # at least one section (only the first section may be untitled).
      def add_section(title = nil, body: '', bullets: nil, numbered: nil, numbered_bullets: false)
        raise ArgumentError, 'Only the first section can have no title' if title.nil? && !@sections.empty?

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
        any_section_numbered = @sections.any?(&:numbered)
        SectionBuilder.debug_header(@sections, any_section_numbered) if @debug
        md = []
        section_counter = 0
        @sections.each_with_index do |section, idx|
          number, section_counter = SectionBuilder.section_number(section, section_counter, any_section_numbered)
          warn "Rendering section #{idx}: #{section.title} with section_number=#{number.inspect}" if @debug
          md << section.render_markdown(section_number: number)
        end
        md.join("\n")
      end

      # Render the entire model as XML. Output is byte-for-byte identical
      # to Python's ``PromptObjectModel.render_xml``.
      def render_xml
        xml = ['<?xml version="1.0" encoding="UTF-8"?>', '<prompt>']
        any_section_numbered = @sections.any?(&:numbered)

        section_counter = 0
        @sections.each do |section|
          section_number, section_counter =
            SectionBuilder.section_number(section, section_counter, any_section_numbered)
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
        target_section = resolve_target_section(target)
        pom_to_add.sections.each do |section|
          target_section.subsections << section
        end
      end

      private

      def resolve_target_section(target)
        case target
        when String
          section = find_section(target)
          raise ArgumentError, "No section with title '#{target}' found." if section.nil?

          section
        when Section
          target
        else
          raise TypeError, 'Target must be a String or a Section object.'
        end
      end
    end

    # Internal: validates raw section Hashes and builds Section trees from
    # them. Mirrors Python's ``build_section`` inner helper. Not part of the
    # public POM surface.
    module SectionBuilder
      module_function

      # Build a Section (recursively) from a Hash section descriptor.
      def build(hash, is_subsection: false)
        validate(hash, is_subsection: is_subsection)

        section = Section.new(hash['title'], **section_kwargs(hash))
        (hash['subsections'] || []).each do |sub|
          section.subsections << build(sub, is_subsection: true)
        end
        section
      end

      def validate(hash, is_subsection: false)
        raise ArgumentError, 'Each section must be a Hash.' unless hash.is_a?(Hash)

        validate_types(hash)
        validate_content(hash)
        raise ArgumentError, 'All subsections must have a title' if is_subsection && !hash.key?('title')
      end

      def validate_types(hash)
        if hash.key?('title') && !hash['title'].is_a?(String)
          raise ArgumentError, "'title' must be a string if present."
        end

        validate_array_field(hash, 'subsections')
        validate_array_field(hash, 'bullets')
        validate_boolean_field(hash, 'numbered')
        validate_boolean_field(hash, 'numberedBullets')
      end

      def validate_array_field(hash, key)
        return unless hash.key?(key) && !hash[key].is_a?(Array)

        raise ArgumentError, "'#{key}' must be an Array if provided."
      end

      def validate_boolean_field(hash, key)
        return unless hash.key?(key) && ![true, false].include?(hash[key])

        raise ArgumentError, "'#{key}' must be a boolean if provided."
      end

      def validate_content(hash)
        return if %w[body bullets subsections].any? { |k| present?(hash, k) }

        raise ArgumentError,
              'All sections must have either a non-empty body, non-empty bullets, or subsections'
      end

      def present?(hash, key)
        hash.key?(key) && hash[key] && !hash[key].empty?
      end

      def section_kwargs(hash)
        kwargs = { body: hash.fetch('body', ''), bullets: hash.fetch('bullets', []) }
        kwargs[:numbered] = hash['numbered'] if hash.key?('numbered')
        kwargs[:numbered_bullets] = hash['numberedBullets'] if hash.key?('numberedBullets')
        kwargs
      end

      # Compute the [section_number, counter] pair for one section, mirroring
      # the Python numbering logic. Untitled sections get an empty number and
      # don't advance the counter.
      def section_number(section, counter, any_section_numbered)
        return [[], counter] if section.title.nil?

        counter += 1
        number = any_section_numbered && section.numbered != false ? [counter] : []
        [number, counter]
      end

      def debug_header(sections, any_section_numbered)
        warn "Any section numbered: #{any_section_numbered}"
        sections.each_with_index do |section, idx|
          warn "Section #{idx + 1}: #{section.title}, numbered=#{section.numbered}"
        end
      end
    end
  end
end
