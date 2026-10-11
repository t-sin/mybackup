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
    @exclude_patterns.map { |pat| "--exclude=#{pat}" }
  end

  def build_command
    options = @options + exclude_options
    cmd = [COMMAND_NAME] + options + [@src, @dest]
    @cmd = cmd
  end

  def run_normally
    MyLogger.pause_file
    succeeded = system(*@cmd)
    exit_code = $CHILD_STATUS
    MyLogger.restart_file

    [succeeded, exit_code]
  end

  def run_dryry
    MyLogger.info 'DRY RUN SO NOT RUN THAT COMMAND'
    [true, 0]
  end

  def run
    build_command

    cmd_pp = ''.dup
    PP.pp @cmd, cmd_pp
    MyLogger.info "command:\n#{cmd_pp}"

    if @dry_run
      run_dryry
    else
      run_normally
    end
  end
end
