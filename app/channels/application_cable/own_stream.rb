module ApplicationCable
  # Turbo keeps its stream name builder private; signing and verifying the
  # streamables gives the plain name to compare a subscription with.
  module OwnStream
    private

    def stream_name_for(streamables)
      self.class.verified_stream_name(self.class.signed_stream_name(streamables))
    end
  end
end
