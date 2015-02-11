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

To run the tests:

`bundle exec rake`

To run only one test file:

`bundle exec rake TEST=path/to/test/file.rb`

To run only a specific test:

`bundle exec rake TESTOPTS="--name=/pattern_to_match_test_name/"`

To run only the adapter's test suite:

`bundle exec rake FB_ONLY=true`
