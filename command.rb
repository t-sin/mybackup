# frozen_string_literal: true

require 'English'
class RsyncCommand
  COMMAND_NAME = 'rsync'
  def initialize(src, dest, dry_run: false, options: [], exclude_patterns: [])
    @src = src
    @dest = dest
    @options = options
    @exclude_patterns = exclude_patterns
    @dry_run = dry_run
  end

  def to_s
    "['#{build_command.join("', '")}'"
  end

  def exclude_options
    @exclude_patterns.map { |pat| "--exclude=\"#{pat}\"" }
  end

  def build_command
    options = @options + exclude_options
    cmd = [COMMAND_NAME] + options + [@src, @dest]
    cmd = ['echo'] + cmd if @dry_run
    cmd
  end

  def run_normally
    MyLogger.pause
    succeeded = system(*build_command)
    exit_code = $CHILD_STATUS
    MyLogger.resume

    [succeeded, exit_code]
  end

  def run_dryry
    MyLogger.info('********** dry run!!!!! **********')
    system(*build_command)
    [true, 0]
  end

  def run
    puts
    succeeded, exit_code = if @dry_run
                             run_dryry
                           else
                             run_normally
                           end
    puts
    [succeeded, exit_code]
  end
end
