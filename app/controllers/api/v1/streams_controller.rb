require 'monitor'

module Api
  module V1
    class StreamsController < ApplicationController
      # In-memory thread-safe signaling hub
      @@lock = Monitor.new
      @@active_stream = {
        active: false,
        stream_id: nil,
        title: '',
        face_index: -1,
        all_faces: true,
        broadcaster_ip: nil,
        lan_bridge_url: nil,
        updated_at: 0
      }
      # receiver_id => Array of signal objects
      @@signal_queues = Hash.new { |h, k| h[k] = [] }

      STREAM_TTL = 35 # seconds before inactive broadcast auto-expires

      # POST /api/v1/stream/cast
      def cast
        active = params[:active] == true || params[:active] == 'true'
        stream_id = params[:stream_id].presence || "stream_#{Time.now.to_i}"
        face_index = params[:face_index].present? ? params[:face_index].to_i : -1
        all_faces = params[:all_faces] != false && params[:all_faces] != 'false'
        title = params[:title].presence || 'Live Video Stream'
        lan_bridge_url = params[:lan_bridge_url].presence

        client_ip = request.remote_ip
        broadcaster_ip = params[:broadcaster_ip].presence || client_ip

        @@lock.synchronize do
          if active
            @@active_stream = {
              active: true,
              stream_id: stream_id,
              title: title,
              face_index: face_index,
              all_faces: all_faces,
              broadcaster_ip: broadcaster_ip,
              lan_bridge_url: lan_bridge_url,
              updated_at: Time.now.to_i
            }
          else
            # Stop broadcast
            if @@active_stream[:active]
              # Notify all listening clients that stream is stopped
              @@signal_queues.each_key do |receiver_id|
                next if receiver_id == 'broadcaster'
                @@signal_queues[receiver_id] << {
                  type: 'stop',
                  stream_id: @@active_stream[:stream_id],
                  timestamp: Time.now.to_i
                }
              end
            end
            @@active_stream = {
              active: false,
              stream_id: nil,
              title: '',
              face_index: -1,
              all_faces: true,
              broadcaster_ip: nil,
              lan_bridge_url: nil,
              updated_at: Time.now.to_i
            }
          end
        end

        render json: { success: true, stream: current_stream_state }
      end

      # GET /api/v1/stream/status
      def status
        render json: current_stream_state
      end

      # POST /api/v1/stream/signal
      def signal
        target = params[:target].to_s.strip
        sender_id = params[:sender_id].to_s.strip
        signal_type = params[:type].to_s.strip
        payload = params[:payload] || params[:data]

        if target.blank? || signal_type.blank?
          render json: { error: 'Missing target or signal type' }, status: :bad_request
          return
        end

        signal_obj = {
          target: target,
          sender_id: sender_id,
          type: signal_type,
          payload: payload,
          timestamp: Time.now.to_i
        }

        @@lock.synchronize do
          # Clean stale queues (empty for more than 10 mins)
          if @@signal_queues.size > 200
            @@signal_queues.delete_if { |_k, v| v.empty? }
          end

          # Add signal to recipient's inbox
          @@signal_queues[target] << signal_obj
          # Keep queue bounded
          @@signal_queues[target] = @@signal_queues[target].last(50) if @@signal_queues[target].size > 50

          # If this is from the broadcaster, update heartbeat
          if sender_id == 'broadcaster' && @@active_stream[:active]
            @@active_stream[:updated_at] = Time.now.to_i
          end
        end

        render json: { success: true }
      end

      # GET /api/v1/stream/signals?receiver_id=...
      def signals
        receiver_id = params[:receiver_id].to_s.strip
        if receiver_id.blank?
          render json: { error: 'receiver_id is required' }, status: :bad_request
          return
        end

        delivered = []
        @@lock.synchronize do
          delivered = @@signal_queues[receiver_id].dup
          @@signal_queues[receiver_id].clear

          # Broadcaster polling also acts as keepalive
          if receiver_id == 'broadcaster' && @@active_stream[:active]
            @@active_stream[:updated_at] = Time.now.to_i
          end
        end

        render json: { signals: delivered }
      end

      private

      def current_stream_state
        @@lock.synchronize do
          # Auto-expire if broadcaster hasn't updated in STREAM_TTL seconds
          if @@active_stream[:active] && (Time.now.to_i - @@active_stream[:updated_at] > STREAM_TTL)
            @@active_stream[:active] = false
          end
          @@active_stream.dup
        end
      end
    end
  end
end
