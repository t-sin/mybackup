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

  def self.method_missing(name, msg, only_stdout: false, only_file: false)
    @@logger.log name, msg, only_stdout:, only_file:
  end

  def self.log(method, msg, only_stdout: false, only_file: false)
    @@logger.log method, msg, only_stdout:, only_file:
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

  def log(method, msg, only_stdout:, only_file:)
    @stdout_logger.public_method(method).call msg unless only_file
    @file_logger.public_method(method).call msg unless only_stdout
  end
end
