# app/jobs/slow_test_job.rb
class SlowTestJob
  include Sidekiq::Job

  def perform(seconds = 120)
    Sidekiq.logger.info "SlowTestJob starting, will run #{seconds}s"
    seconds.times { sleep 1 }
    Sidekiq.logger.info "SlowTestJob finished cleanly"
  end
end
