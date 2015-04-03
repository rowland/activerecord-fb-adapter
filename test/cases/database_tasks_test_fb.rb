require 'cases/fb_helper'
require 'fileutils'

# This error class is loaded after the tasks start to run. It is defined here
# simply so that it can be referenced in the test
class ActiveRecord::Tasks::DatabaseAlreadyExists < StandardError; end

class DatabaseTasksTestFb < ActiveSupport::TestCase
  def setup
    ar_config = YAML.load ERB.new(File.read(ENV['ARCONFIG'])).result
    @config = ar_config['fbunit_tasks']
    database_tasks.stubs(:isql_executable).returns('isql')
    database_tasks.stubs(:establish_connection)
  end

  def teardown
    FileUtils.rm fdb_file if File.exist?(fdb_file)
  end

  def test_create_database
    assert !File.exist?(fdb_file)
    database_tasks.create
    assert File.exist?(fdb_file)
  end

  def test_create_database_when_exists
    database_tasks.create
    assert File.exist?(fdb_file)
    assert_raises ActiveRecord::Tasks::DatabaseAlreadyExists do
      database_tasks.create
    end
  end

  def test_drop_database
    database_tasks.create
    assert File.exist?(fdb_file)
    database_tasks.drop
    assert !File.exist?(fdb_file)
  end

  def test_drop_database_when_not_exists
    assert !File.exist?(fdb_file)
    assert_raises ActiveRecord::ConnectionNotEstablished do
      database_tasks.drop
    end
  end

  def test_structure_dump
    expr = /isql(.+)-output FILE(.+)-user(.+)-password(.+) -extract/
    Kernel.expects(:system).with(regexp_matches(expr)).returns(true)
    database_tasks.create
    database_tasks.structure_dump('FILE')
  end

  def test_structure_load
    expr = /isql(.+)-input FILE(.+)-user(.+)-password(.+)/
    Kernel.expects(:system).with(regexp_matches(expr)).returns(true)
    database_tasks.create
    database_tasks.structure_load('FILE')
  end

  private

  def fdb_file
    File.expand_path @config['database'], ARTest::Fb.root_fb
  end

  def database_tasks
    @tasks ||= ActiveRecord::Tasks::FbDatabaseTasks.new(@config, ARTest::Fb.root_fb)
  end
end if ::ActiveRecord::VERSION::MAJOR > 3
