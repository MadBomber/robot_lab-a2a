# frozen_string_literal: true

module RobotLab
  module A2A
    # Tracks live robot threads for in-progress interactive runs.
    # Keyed by A2A task_id. Entries are removed when the robot thread finishes.
    class Registry
      Entry = Data.define(:thread, :event_queue, :answer_queue)

      @mutex   = Mutex.new
      @entries = {}

      class << self
        def register(task_id, entry)
          @mutex.synchronize { @entries[task_id] = entry }
        end

        def fetch(task_id)
          @mutex.synchronize { @entries[task_id] }
        end

        def delete(task_id)
          @mutex.synchronize { @entries.delete(task_id) }
        end

        def size
          @mutex.synchronize { @entries.size }
        end

        def clear
          @mutex.synchronize { @entries.clear }
        end
      end
    end
  end
end
