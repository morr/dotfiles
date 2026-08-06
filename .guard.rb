# Publish the rspec run outcome to WezTerm as the pane user var `guard_status`
# (running | pass | fail), which ~/.wezterm.lua renders as a coloured dot in the
# tab title. Loaded by guard for every project (~/.guard.rb is appended to the
# Guardfile), so it must no-op when guard-rspec isn't in use.
if defined?(Guard::RSpec)
  module GuardWeztermStatus
    OSC_USER_VAR = "\e]1337;SetUserVar=guard_status=%s\a"

    def self.publish state
      return unless $stdout.tty?

      sequence = format(OSC_USER_VAR, [state].pack('m0'))
      # tmux swallows unknown OSCs unless they're wrapped in a passthrough.
      sequence = "\ePtmux;#{sequence.gsub("\e", "\e\e")}\e\\" if ENV['TMUX']

      $stdout.write sequence
      $stdout.flush
    rescue IOError, Errno::EPIPE
      nil
    end

    def run_all
      _wezterm_status { super }
    end

    def run_on_modifications paths
      return super if paths.empty?

      _wezterm_status { super }
    end

    private

    def _wezterm_status
      GuardWeztermStatus.publish 'running'

      passed = false
      result = catch(:task_has_failed) do
        value = yield
        passed = true
        value
      end

      GuardWeztermStatus.publish(passed ? 'pass' : 'fail')
      throw :task_has_failed unless passed

      result
    rescue StandardError
      GuardWeztermStatus.publish 'fail'
      raise
    end
  end

  Guard::RSpec.prepend GuardWeztermStatus
  at_exit { GuardWeztermStatus.publish '' }
end
