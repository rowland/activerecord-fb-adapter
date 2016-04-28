require 'active_record/connection_adapters/fb_adapter'

module ActiveRecordFbAdapter

  if defined?(::Rails::Railtie) && ::ActiveRecord::VERSION::MAJOR > 3
    class Railtie < ::Rails::Railtie
      rake_tasks do
        load 'active_record/tasks/fb_database_tasks.rb'
        ActiveRecord::Tasks::DatabaseTasks.register_task(/fb/, ActiveRecord::Tasks::FbDatabaseTasks)
      end
    end
  end

end
