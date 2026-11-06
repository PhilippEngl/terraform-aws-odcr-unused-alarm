resource "aws_sns_topic" "this" {
  #checkov:skip=CKV_AWS_26: "Encryption is var.sns_kms_master_key_id and defaults to off, because the AWS-managed aws/sns key cannot be used here: its key policy cannot be edited to let cloudwatch.amazonaws.com and events.amazonaws.com use it, so alarms would fail to publish silently. Supply a customer-managed key whose policy grants both services kms:GenerateDataKey* and kms:Decrypt."

  count = var.create_sns_topic ? 1 : 0

  name              = local.name
  kms_master_key_id = var.sns_kms_master_key_id

  tags = merge(var.tags, {
    Name = local.name
  })
}

# The topic policy is replaced wholesale, so it has to restate what the default policy gave the
# owning account as well as add the two service principals. Without the events.amazonaws.com
# statement the Health rule's deliveries fail and nothing reports it.
data "aws_iam_policy_document" "topic" {
  count = var.create_sns_topic ? 1 : 0

  statement {
    sid    = "OwnerManagesTopic"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish",
    ]
    resources = [aws_sns_topic.this[0].arn]
  }

  statement {
    sid    = "AwsServicesPublishFromThisAccount"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com", "events.amazonaws.com"]
    }

    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.this[0].arn]

    # Confused-deputy guard: only alarms and rules owned by this account may publish.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "this" {
  count = var.create_sns_topic ? 1 : 0

  arn    = aws_sns_topic.this[0].arn
  policy = data.aws_iam_policy_document.topic[0].json
}

# Email subscriptions stay PendingConfirmation until someone clicks the link AWS sends. Terraform
# reports success either way, so an unconfirmed address looks deployed and receives nothing.
resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.email_subscriptions)

  topic_arn = local.topic_arn
  protocol  = "email"
  endpoint  = each.key
}
