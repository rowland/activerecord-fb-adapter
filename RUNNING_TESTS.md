# How to Run the Tests

## Bundling

This adapter runs the ActiveRecord test cases provided by Rails. When you run bundle, a version of Rails specified by this project's gemspec will be cloned for you.

To bundle with the target Rails version:

`bundle install`

To bundle with a specific version of Rails:

`export RAILS_VERSION=3.2.14`
`bundle install`

To bundle with your local clone of Rails:

`export RAILS_SOURCE=../rails`
`bundle install`

## Configuring test databases

By default, the tests will create a database in the project root directory in a folder called db. If you want to create your databases in a different folder, you can modify `test/config.yml`.

## Running the tests

To run the tests, simply run `bundle exec rake`. I recommend redirecting the test into a log like this:

`bundle exec rake | tee 4.2.results.log`

| Command                                                 | Description                                       |
|:--------------------------------------------------------|:------------------------------------------------- |
| bundle exec rake                                        | Run ActiveRecord and Firebird's test suites       |
| bundle exec rake TEST=path/to/test.rb                   | Run a specific test from Firebird's suite         |
| bundle exec rake AR_TEST=migrations_test.rb             | Run a specific test from ActiveRecord             |
| bundle exec rake TESTOPTS='--name=/test_something/'     | Run a test named 'test_something'                 |
| bundle exec rake SMOKE=true                             | Run just a few tests that identify major problems |

Please run all tests before contributing.
