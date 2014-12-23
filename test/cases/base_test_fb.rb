# encoding: UTF-8
require File.expand_path('../fb_helper', __FILE__)
require 'models_fb/foo'

class BaseTestFb < ActiveRecord::TestCase
  delegate :fb_connection_config, to: ActiveRecord::Base

  def setup
    @config_without_host = {
      'database' => 'db/development.fdb',
      'username' => 'sysdba',
      'password' => 'masterkey'
    }

    @config_with_localhost = @config_without_host.merge({
      'host' => 'localhost'
    })

    @config_with_host = @config_without_host.merge({
      'host'     => 'example.com',
      'database' => '/db/production.fdb'
    })

    @config_with_port = @config_with_host.merge({'port' => 9999})
  end

  def test_fb_connection_config
    assert_equal fb_connection_config(@config_without_host), {
      :downcase_names => true,
      :database => File.expand_path(@config_without_host['database']),
      :username => 'sysdba',
      :password => 'masterkey',
      :port     => 3050
    }
  end

  def test_fb_connection_config_with_localhost
    path = File.expand_path(@config_with_localhost['database'])
    assert_equal fb_connection_config(@config_with_localhost), {
      :downcase_names => true,
      :database => "localhost/3050:#{path}",
      :username => 'sysdba',
      :password => 'masterkey',
      :host     => 'localhost',
      :port     => 3050
    }
  end

  def test_fb_connection_config_with_host
    assert_equal fb_connection_config(@config_with_host), {
      :downcase_names => true,
      :database => 'example.com/3050:/db/production.fdb',
      :username => 'sysdba',
      :password => 'masterkey',
      :host     => 'example.com',
      :port     => 3050
    }
  end

  def test_fb_connection_config_with_port
    assert_equal fb_connection_config(@config_with_port), {
      :downcase_names => true,
      :database => 'example.com/9999:/db/production.fdb',
      :username => 'sysdba',
      :password => 'masterkey',
      :host     => 'example.com',
      :port     => 9999
    }
  end
end
