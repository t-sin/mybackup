# frozen_string_literal: true

require 'logger'

class MyLogger
  def self.setup(level, file)
    level = level.upcase.intern
    @@logger = new level, file
  end

  def self.pause
    @@logger.start_file_logger
  end

  def self.resume
    @@logger.stop_file_logger
  end

  def self.method_missing(name, msg)
    @@logger.log name, msg
  end

  def self.log(method, msg)
    @@logger.log method, msg
  end

  def start_file_logger
    file = File.open @file, mode: 'a'
    @file_logger = Logger.new(file, level: @level)
  end

  def stop_file_logger
    @file_logger.close
    @file_logger = nil
  end

  def initialize(level, file)
    @level = level
    @file = file

    @stdout_logger = Logger.new($stdout, level: @level, skip_header: true)
    start_file_logger
  end

  def log(method, msg)
    @stdout_logger.public_method(method).call msg
    @file_logger&.public_method(method)&.call msg
  end
end
