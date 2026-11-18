# frozen_string_literal: true

require 'English'
require 'open3'

class Command
  COMMAND_NAME = nil

  def initialize(dry_run: false)
    @dry_run = dry_run
  end

  def build_command
    options = @options
    cmd = [COMMAND_NAME] + options
    @cmd = cmd
  end

  def to_s
    "['#{build_command.join("', '")}'"
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
    build_command if @cmd.nil?

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

class SshAddCommand < Command
  COMMAND_NAME = 'ssh-add'

  def initialize(identity_file, dry_run: false)
    super(dry_run: dry_run)
    @identity_file = identity_file
  end

  def build_command
    @cmd = [COMMAND_NAME, @identity_file]
  end
end

class SshAgentCommand < Command
  COMMAND_NAME = 'ssh-agent'

  def initialize(dry_run: false)
    super
  end

  def start
    @cmd = [COMMAND_NAME, '-s']
    if @dry_run
      run
      return
    end

    output, = Open3.capture2 @cmd
    output.lines.each do |line|
      line.scan(/([[:alnum:]_]+)=([^;]+);/) do |key, val|
        MyLogger.info "adding environment var: #{key} = #{val}"
        ENV[key] = val
      end
    end
  end

  def stop
    @cmd = [COMMAND_NAME, '-k']
    if @dry_run
      run
      return
    end

    return unless ENV['SSH_AGENT_PID']

    run
  end
end

class RsyncCommand < Command
  COMMAND_NAME = 'rsync'
  def initialize(src, dest, dry_run: false, options: [], exclude_patterns: [])
    super(dry_run: dry_run)
    @src = src
    @dest = dest
    @options = options
    @exclude_patterns = exclude_patterns
  end

  def exclude_options
    @exclude_patterns.map { |pat| "--exclude=#{pat}" }
  end

  def build_command
    options = @options + exclude_options
    cmd = [COMMAND_NAME] + options + [@src, @dest]
    @cmd = cmd
  end
end
