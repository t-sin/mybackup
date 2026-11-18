# frozen_string_literal: true

require 'optparse'
require 'pp'

class MyBackup
  PROG_NAME = 'mybackup'
  PORG_VERSION = '0.1.0'

  OP_LIST_TARGETS = :'op::list_targets'
  OP_SHOW_CONFIG = :'op::show_config'
  OP_BACKUP_ALL = :'op::backup_all'
  OP_BACKUP_IDS = :'op::backup_ids'
end

def parse_opt(argv)
  opt = OptionParser.new
  opt.banner = "Usage: #{MyBackup::PROG_NAME} [CONFIG_PATH]"
  opt.version = MyBackup::PORG_VERSION
  opt.on('-i IDS', '--ids', 'Run backups specified with comma-separated IDS.') { |v| v }
  opt.on('-l', '--list', 'List all backup targets.') { |v| v }
  opt.on('-c', '--config', 'Show configuration.') { |v| v }
  opt.on('-n', '--dry-run', 'Run backup without actual rsync command.') { |v| v }

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
  MyLogger.info "=== preparing for #{config.operation}..."

  ssh_agent = SshAgentCommand.new(dry_run: config.dry_run)
  ssh_agent.start

  added_keys = []
  backups.each do |b|
    MyLogger.debug "added_keys = #{added_keys}"
    next unless b.instance_of?(RemoteBackup) && !added_keys.include?(b.identity_file)

    b.setup config
    MyLogger.info "ssh key added: #{b.identity_file}"
    added_keys.push b.identity_file
  end
  MyLogger.info '=== preparation finished.'

  start_at = Time.now
  MyLogger.info "=== start backup operation at #{start_at.iso8601}"

  begin
    backups.each { |b| op_backup_one b, config }
  ensure
    ssh_agent.stop

    end_at = Time.now
    MyLogger.info "finished backup operation at #{end_at.iso8601}"
    MyLogger.info "it took #{format_sec(end_at - start_at)}"
  end
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
  when MyBackup::OP_BACKUP_ALL
    op_backup_all backups, config
  when MyBackup::OP_BACKUP_IDS
    targets = backups.select { |b| config.target_ids.include? b.id }
    op_backup_all targets, config
  else
    msg = "unknown operation: #{op}"
    MyLogger.fatal msg
    exit 1
  end
end

main config
