from flask import Flask, request, jsonify
import time
import threading

app = Flask(__name__)

# client_id -> list[timestamps]
rate_limit = {}
LOCK = threading.Lock()

WINDOW = 5          # seconds
MAX_MSG = 5         # messages

@app.route('/rate_limit', methods=['POST'])
def rate_limit_check():
    data = request.get_json(force=True)

    client_id = data.get('client_id')
    if not client_id:
        return jsonify({'status': 'DENY'}), 400

    now = time.time()

    with LOCK:
        timestamps = rate_limit.get(client_id, [])

        # remove old timestamps
        timestamps = [t for t in timestamps if now - t <= WINDOW]

        if len(timestamps) >= MAX_MSG:
            rate_limit[client_id] = timestamps
            return jsonify({'status': 'DENY'}), 403

        # allow
        timestamps.append(now)
        rate_limit[client_id] = timestamps

    return jsonify({'status': 'ALLOW'}), 200


if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000, threaded=True)
