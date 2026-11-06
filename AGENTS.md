# Working in this repository

This is a Terraform **module**, not a deployable configuration. It is never applied directly: the root configuration is `examples/targeted-odcrs`, and `TF_DIR` selects it. `make help` lists every target.

`README.md` explains what the module builds and why. This file covers only what you cannot learn by reading the code and config.

## Gates

`make fmt-check validate validate-examples test-tf lint docs-check scan` all run with no AWS credentials and nothing deployed. Run the ones your change could plausibly break, and `make scan` before declaring any change done.

## What is verified, and what is not

**Taken from AWS documentation, not observed in a deployment of this module:** the `AWS/EC2CapacityReservations` namespace, the `AvailableInstanceCount` metric and its dimensions (`CapacityReservationId`, `InstanceType`, and none); the five-minute publishing interval; the two Health event type codes and the 20 percent threshold behind them; CloudWatch's seven-day cap on period times evaluation periods and its five-actions limit.

**Verified by a gate:** input validations, derived names, and the alarm shape (`make test-tf`).

**Derived and not observed.** The most likely places for a first apply to go wrong:

- **The Health event pattern.** It filters on `detail.service = EC2` and the two `eventTypeCode` values, as in the documented examples. Nobody has yet watched one of these events arrive through the rule.
- **The topic policy.** It restates the owner statement the default policy would have contained, because `aws_sns_topic_policy` replaces the whole policy. If an operator loses access to manage the topic, look here first.

Update this section when one of these moves from derived to observed.

## Invariants a change must preserve

**Alarms evaluate on `Minimum` over one-hour periods, every period breaching.** `Average` or an M-of-N setting makes a brief gap during a node replacement fire the alarm, and an alarm that cries wolf gets muted.

**The module never modifies a topic it did not create.** With `create_sns_topic = false` the caller owns the topic policy.

## Conventions

Same as the sibling modules: comments explain why, not what; cross-variable rules live in `validation` blocks; every security suppression carries its reasoning inline; run `make docs` after touching any variable or output.
