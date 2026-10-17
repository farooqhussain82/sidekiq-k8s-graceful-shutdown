# Sidekiq graceful shutdown on Kubernetes

Stop Kubernetes deploys from killing long-running Sidekiq jobs.

When Kubernetes stops a pod it sends `SIGTERM` and, after `terminationGracePeriodSeconds` (30s by default), `SIGKILL`. Sidekiq's default shutdown timeout is 25s. Any job that runs longer gets cut off mid-run.

This repo is the working config behind the article:
**[Your Deploys Are Killing Sidekiq Jobs. Here's the Fix.](https://medium.com/@farooq.hussain/sidekiq-kubernetes-graceful-shutdown-prestop-hook-5a0aac60e712)**

## How it works

1. A `preStop` hook sends `TSTP` to Sidekiq (quiet mode: stop fetching new jobs).
2. The hook waits until this pod has no busy jobs, up to `SIDEKIQ_DRAIN_SECONDS`.
3. Kubernetes then sends `SIGTERM`, and Sidekiq exits cleanly with nothing left to do.
4. `terminationGracePeriodSeconds` is set longer than the drain time plus Sidekiq's timeout.

```text
terminationGracePeriodSeconds > drain time + Sidekiq :timeout: + buffer
600                           > 540        + 25                + 35
```

## Files

| File | Purpose |
|---|---|
| `sidekiq-prestop.sh` | preStop drain script (put it at `bin/sidekiq-prestop.sh` in your app) |
| `deployment.yaml` | Worker Deployment with the preStop hook, grace period, and rolling update settings |
| `pdb.yaml` | PodDisruptionBudget so node drains evict one worker at a time |
| `sidekiq.yml` | Sidekiq config with the shutdown timeout |
| `Dockerfile.example` | Copies the script and runs Sidekiq as PID 1 (exec form) |
| `docker-entrypoint.sh` | Entrypoint that `exec`s Sidekiq so signals reach it |
| `slow_test_job.rb` | Test job to prove the drain works |

## Test it

```sh
kubectl exec -it deploy/sidekiq-worker -- bundle exec rails runner 'SlowTestJob.perform_async(120)'
kubectl delete pod <pod-running-the-job>
kubectl logs -f <pod-running-the-job>
```

You should see `SlowTestJob finished cleanly` and `Bye!` before the pod goes away.

## Gotchas

- Sidekiq must be PID 1, or `kill -TSTP 1` never reaches it.
- The grace period clock includes the preStop hook time.
- Jobs should still be idempotent. Crashes and force-deletes skip the hook.

MIT licensed. Use it, change it.
