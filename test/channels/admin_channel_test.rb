require "test_helper"

# Only administrators hear the admin pages' refresh signals (specs/admin.md).
class AdminChannelTest < ActionCable::Channel::TestCase
  test "administrators subscribe; agents, requesters and visitors are rejected" do
    signed = Turbo::StreamsChannel.signed_stream_name(:admin)

    stub_connection current_user: users(:admin)
    subscribe signed_stream_name: signed
    assert subscription.confirmed?

    [ users(:agent), users(:anna), nil ].each do |user|
      stub_connection current_user: user
      subscribe signed_stream_name: signed
      assert subscription.rejected?
    end
  end
end
