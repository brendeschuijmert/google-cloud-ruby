# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require "helper"

describe Gcloud::Pubsub::Subscription, :pull, :mock_pubsub do
  let(:topic_name) { "topic-name-goes-here" }
  let(:sub_name) { "subscription-name-goes-here" }
  let(:sub_json) { subscription_json topic_name, sub_name }
  let(:sub_hash) { JSON.parse sub_json }
  let(:sub_grpc) { Google::Pubsub::V1::Subscription.decode_json(sub_json) }
  let(:subscription) { Gcloud::Pubsub::Subscription.from_grpc sub_grpc, pubsub.connection, pubsub.service }

  it "can pull messages" do
    rec_message_msg = "pulled-message"

    pull_req = Google::Pubsub::V1::PullRequest.new(
      subscription: subscription_path(sub_name),
      return_immediately: true,
      max_messages: 100
    )
    pull_res = Google::Pubsub::V1::PullResponse.decode_json rec_messages_json(rec_message_msg)
    mock = Minitest::Mock.new
    mock.expect :pull, pull_res, [pull_req]
    subscription.service.mocked_subscriber = mock

    rec_messages = subscription.pull

    mock.verify

    rec_messages.wont_be :empty?
    rec_messages.first.message.data.must_equal rec_message_msg
  end

  describe "lazy subscription object of a subscription that does exist" do
    let :subscription do
      Gcloud::Pubsub::Subscription.new_lazy sub_name,
                                            pubsub.connection, pubsub.service
    end

    it "can pull messages" do
      rec_message_msg = "pulled-message"

      pull_req = Google::Pubsub::V1::PullRequest.new(
        subscription: subscription_path(sub_name),
        return_immediately: true,
        max_messages: 100
      )
      pull_res = Google::Pubsub::V1::PullResponse.decode_json rec_messages_json(rec_message_msg)
      mock = Minitest::Mock.new
      mock.expect :pull, pull_res, [pull_req]
      subscription.service.mocked_subscriber = mock

      rec_messages = subscription.pull

      mock.verify

      rec_messages.wont_be :empty?
      rec_messages.first.message.data.must_equal rec_message_msg
    end
  end

  describe "lazy subscription object of a subscription that does not exist" do
    let :subscription do
      Gcloud::Pubsub::Subscription.new_lazy sub_name,
                                            pubsub.connection, pubsub.service
    end

    it "raises NotFoundError when pulling messages" do
      stub = Object.new
      def stub.pull *args
        raise GRPC::BadStatus.new 5, "not found"
      end
      subscription.service.mocked_subscriber = stub

      expect do
        subscription.pull
      end.must_raise Gcloud::NotFoundError
    end
  end
end
