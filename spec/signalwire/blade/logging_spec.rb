# frozen_string_literal: true

require 'spec_helper'

describe Signalwire::Blade::Logging do
  class Foo
    include Signalwire::Blade::Logging::HasLogger
    class Bar
      include Signalwire::Blade::Logging::HasLogger
    end
  end

  before :all do
    ::Logging.shutdown
    ::Logging.reset
    Signalwire::Blade::Logging.init
  end

  before do
    Signalwire::Blade::Logging.start
    Signalwire::Blade::Logging.silence!
  end

  after :all do
    Signalwire::Blade::Logging.silence!
  end

  it 'should be added to any instance' do
    expect(Foo.new).to respond_to :logger
    expect(Foo::Bar.new).to respond_to :logger
  end

  it 'should create the predefined set of log levels' do
    expect(::Logging::LEVELS.keys).to eq(Signalwire::Blade::Logging::LOG_LEVELS.map(&:downcase))
  end

  it 'should log to the Object logger when given arguments' do
    message = 'o hai. ur home erly.'
    foo = Foo.new
    expect(::Logging.logger[Foo]).to receive(:info).once.with(message)
    foo.logger.info message
  end

  it 'should log to the Object logger when given arguments (II)' do
    message = 'o hai. ur home erly.'
    bar = Foo::Bar.new
    expect(::Logging.logger[Foo::Bar]).to receive(:info).once.with(message)
    bar.logger.info message
  end

  it 'initializes properly a Logging object' do
    expect(::Logging.logger.root.appenders.length).to eql(1)
    expect(::Logging.logger.root.appenders.select { |a| a.is_a?(::Logging::Appenders::Stdout) }.length).to eql(1)
  end

  it 'initializes properly a Logging object with log level as parameter' do
    Signalwire::Blade::Logging.start(:debug)
    expect(::Logging.logger.root.level).to eql(::Logging::LEVELS['debug'])
  end

  it 'should create only a Logging object per Class (reuse per all the instances)' do
    _logger = Foo.new.logger
    10.times do
      expect(Foo.new.logger.object_id).to eql(_logger.object_id)
    end
  end

  it 'should reuse a Logging instance in all Class instances but not with child instances' do
    _foo_logger = Foo.new.logger
    _bar_logger = Foo::Bar.new.logger
    expect(_foo_logger.object_id).not_to eql(_bar_logger)
  end

  describe 'level changing' do
    before  { Signalwire::Blade::Logging.unsilence! }
    after   { Signalwire::Blade::Logging.unsilence! }

    fit 'changing the logging level should affect all loggers' do
      loggers = [::Foo.new.logger, ::Foo::Bar.new.logger]
      expect(loggers.map(&:level)).not_to eq([Signalwire::Blade::Logging::DEBUG] * 2)
      expect(loggers.map(&:level)).to eq([Signalwire::Blade::Logging::INFO] * 2)
      Signalwire::Blade::Logging.logging_level = :warn
      expect(loggers.map(&:level)).to eq([Signalwire::Blade::Logging::WARN] * 2)
    end

    it 'changing the logging level, using level=, should affect all loggers' do
      loggers = [Foo.new.logger, ::Foo::Bar.new.logger]
      expect(loggers.map(&:level)).not_to eq([::Logging::LEVELS['debug']] * 2)
      expect(loggers.map(&:level)).to eq([::Logging::LEVELS['info']] * 2)
      Signalwire::Blade::Logging.level = :warn
      expect(loggers.map(&:level)).to eq([::Logging::LEVELS['warn']] * 2)
    end

    it 'should change all the Logger instance level' do
      expect(Foo.new.logger.level).to be Signalwire::Blade::Logging::INFO
      Signalwire::Blade::Logging.logging_level = :fatal
      expect(Foo.new.logger.level).to be Signalwire::Blade::Logging::FATAL
    end

    it 'a new logger should have the :root logging level' do
      expect(Foo.new.logger.level).to be Signalwire::Blade::Logging::INFO
      Signalwire::Blade::Logging.logging_level = :fatal
      expect(Foo::Bar.new.logger.level).to be Signalwire::Blade::Logging::FATAL
    end

    it '#silence! should change the level to be FATAL' do
      Signalwire::Blade::Logging.silence!
      expect(Signalwire::Blade::Logging.logging_level).to be(Signalwire::Blade::Logging::FATAL)
    end

    it '#unsilence! should change the level to be INFO' do
      Signalwire::Blade::Logging.unsilence!
      expect(Signalwire::Blade::Logging.logging_level).to be(Signalwire::Blade::Logging::INFO)
    end
  end
end
