# frozen_string_literal: true

require 'optparse'
require 'yaml'

def must_have_key!(yaml, key)
  return if yaml.key? key

  puts "yaml has no key: #{key}."
  exit 1
end

def must_be!(yaml, key, mod)
  val = yaml[key]
  klass = val.class

  return if val.is_a? mod

  puts "yaml[#{key}] must be a #{mod} but actually #{klass}."
  exit 1
end

def read_config_yaml(path, opt)
  unless File.exist? path
    puts "file #{path} does not exist."
    opt.help_exit
  end

  YAML.load_file(path)
end

def validate_yaml(yaml)
  must_have_key! yaml, 'log'
  must_be! yaml, 'log', Hash

  log = yaml['log']
  must_have_key! log, 'level'
  must_be! log, 'level', String
  must_have_key! log, 'directory'
  must_be! log, 'directory', String

  must_have_key! yaml, 'backups'
  must_be! yaml, 'backups', Array

  must_be! yaml, 'exclude_patterns', Array if yaml.key? 'exclude_patterns'
end

class MybackupConfig
  attr_reader :operation, :dry_run, :log_file, :log_level, :backups, :exclude_patterns, :target_ids

  DATE_FORMAT = '%Y-%m-%d'

  def configure_operation(params)
    @operation = if params[:list]
                   MyBackup::OP_LIST_TARGETS
                 elsif params[:config]
                   MyBackup::OP_SHOW_CONFIG
                 elsif params[:ids]
                   @target_ids = params[:ids].split(',').collect(&:strip)
                   MyBackup::OP_BACKUP_IDS
                 else
                   MyBackup::OP_BACKUP_ALL
                 end
  end

  def configure_dry_run(params)
    dry_run_key = :'dry-run'
    @dry_run = false
    @dry_run = if params.key?(dry_run_key) && params[dry_run_key]
                 true
               else
                 false
               end
  end

  def configure_from_yaml(yaml)
    now_date = Time.now.strftime DATE_FORMAT

    log = yaml['log']
    @log_level = log['level']
    log_dir = File.realpath File.expand_path log['directory']
    log_file = "mybackup_#{now_date}.log"
    @log_file = "#{log_dir}/#{log_file}"

    @exclude_patterns = yaml['exclude_patterns'] || []
    @backups = yaml['backups']
  end

  def initialize(argv, params, opt)
    configure_operation params
    configure_dry_run params

    yaml = read_config_yaml argv[0], opt
    validate_yaml yaml
    configure_from_yaml yaml
  end

  def to_h
    {
      'operation' => @operation,
      'target_ids' => @target_ids,
      'dry_run' => @dry_run,
      'log_level' => @log_level,
      'log_file' => @log_file,
      'exclude_patterns' => @exclude_patterns,
      'backups' => @backups
    }
  end

  def to_s
    YAML.dump to_h
  end
end
