# frozen_string_literal: true

require 'optparse'
require 'pp'

class MyBackup
  PROG_NAME = 'mybackup'
  PORG_VERSION = '0.1.0'

  OP_LIST_TARGETS = :'op::list_targets'
  OP_SHOW_CONFIG = :'op::show_config'
  OP_BACKUP_ALL = :'op::backup_all'
  OP_BACKUP_ONE = :'op::backup_one'
end

def parse_opt(argv)
  opt = OptionParser.new
  opt.banner = "Usage: #{MyBackup::PROG_NAME} [CONFIG_PATH]"
  opt.version = MyBackup::PORG_VERSION
  opt.on('-l', '--list', 'List all backup targets.') { |v| v }
  opt.on('-c', '--config', 'Show configuration.') { |v| v }
  opt.on('-n', '--dry-run', 'Run backup without actual rsync command.') { |v| v }
  opt.on('-i ID', '--id', 'Run a backup specified with ID.') { |v| v }

  params = {}

  opt.parse!(argv, into: params)
  opt.help_exit if argv.count != 1

  [argv, params, opt]
end

argv, params, opt = parse_opt ARGV.dup

require_relative 'config'
config = MybackupConfig.new argv, params, opt

require_relative 'logger'
MyLogger.setup(config.log_level, config.log_file)
# MyLogger.debug PP.pp config.to_h

require_relative 'backup'
require_relative 'command'

def format_sec(sec)
  sec = sec.truncate
  min, sec = sec.divmod(60)
  hour, min = min.divmod(60)

  "#{hour}h #{min}m #{sec}s"
end

def ask_id_files(backups)
  remotes = backups.select { |b| b.instance_of? RemoteBackup }
  MyLogger.info "there are #{remotes.count} RemoteBackups."
  MyLogger.info 'used keys are:'
  remotes.each do |r|
    MyLogger.info "- #{r.identity_file} (in backup '#{r.name}')"
  end
  MyLogger.info 'did you add these keys to ssh agent?'
  MyLogger.info 'asking passphrase stops this backup if you did not that.'

  is_ok = false
  until is_ok
    MyLogger.info 'ok? (yes/no)'
    input = begin
      $stdin.readline.chop
    rescue Interrupt
      exit 1
    end
    exit 1 if input == 'no'

    is_ok = input.chomp == 'yes'
  end
end

def op_backup_one(backup, config)
  b = backup
  start_at = Time.now
  MyLogger.info "start backup #{b.name} at #{start_at.iso8601}"

  b.backup config

  end_at = Time.now
  MyLogger.info "finished backup #{b.name} at #{end_at.iso8601}"
  MyLogger.info "it took #{format_sec(end_at - start_at)}"
  MyLogger.info ''
end

def op_backup_all(backups, config)
  ask_id_files backups

  start_at = Time.now
  MyLogger.info "=== start backup operation at #{start_at.iso8601}"

  backups.each { |b| op_backup_one b, config }

  end_at = Time.now
  MyLogger.info "finished backup operation at #{end_at.iso8601}"
  MyLogger.info "it took #{format_sec(end_at - start_at)}"
end

def main(config)
  MyLogger.info "operation = #{config.operation}"
  backups = config.backups.map { |b| Backup.from_h b }

  case config.operation
  when MyBackup::OP_SHOW_CONFIG
    MyLogger.info config
  when MyBackup::OP_LIST_TARGETS
    backups.each do |b|
      b.to_ss.each { |s| MyLogger.info s }
    end
  when MyBackup::OP_BACKUP_ONE
    backup = backups.select { |b| b.id == config.target_id }.first
    if backup.nil?
      MyLogger.fatal "no such backup: id = #{config.target_id}"
      exit 1
    end

    op_backup_one backup, config
  when MyBackup::OP_BACKUP_ALL
    op_backup_all backups, config
  else
    msg = "unknown operation: #{op}"
    MyLogger.fatal msg
    exit 1
  end
end

main config
