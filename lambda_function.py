import os
import json
import urllib.request
import boto3
from datetime import datetime, timedelta, timezone

def format_game_data(game, playbyplay_data=None):
    status = game.get("Status", "Unknown")
    away_team = game.get("AwayTeam", "Unknown")
    home_team = game.get("HomeTeam", "Unknown")
    final_score = f"{game.get('AwayTeamScore', 'N/A')}-{game.get('HomeTeamScore', 'N/A')}"
    start_time = game.get("DateTime", "Unknown")
    channel = game.get("Channel", "Unknown")
    
    # Format quarters
    quarters = game.get("Quarters", [])
    quarter_scores = ', '.join([f"Q{q['Number']}: {q.get('AwayScore', 'N/A')}-{q.get('HomeScore', 'N/A')}" for q in quarters])
    
    # Play-by-play data (if available)
    play_by_play_info = ""
    if playbyplay_data:
        last_play = playbyplay_data.get("LastPlay", "N/A")
        play_by_play_info = f"\nLast Play: {last_play}"

    if status == "Final":
        return (
            f"Game Status: {status}\n"
            f"{away_team} vs {home_team}\n"
            f"Final Score: {final_score}\n"
            f"Start Time: {start_time}\n"
            f"Channel: {channel}\n"
            f"Quarter Scores: {quarter_scores}\n"
            f"{play_by_play_info}"
        )
    elif status == "InProgress":
        last_play = game.get("LastPlay", "N/A")
        return (
            f"Game Status: {status}\n"
            f"{away_team} vs {home_team}\n"
            f"Current Score: {final_score}\n"
            f"Last Play: {last_play}\n"
            f"Channel: {channel}\n"
            f"{play_by_play_info}"
        )
    elif status == "Scheduled":
        return (
            f"Game Status: {status}\n"
            f"{away_team} vs {home_team}\n"
            f"Start Time: {start_time}\n"
            f"Channel: {channel}\n"
        )
    else:
        return (
            f"Game Status: {status}\n"
            f"{away_team} vs {home_team}\n"
            f"Details are unavailable at the moment.\n"
        )

def lambda_handler(event, context):
    # Get environment variables
    api_key = os.getenv("NBA_API_KEY")
    sns_topic_arn = os.getenv("SNS_TOPIC_ARN")
    sns_client = boto3.client("sns")
    
    # Adjust for Central Time (UTC-6)
    utc_now = datetime.now(timezone.utc)
    central_time = utc_now - timedelta(hours=6)  # Central Time is UTC-6
    today_date = central_time.strftime("%Y-%m-%d")
    
    print(f"Fetching games for date: {today_date}")
    
    # Fetch game data from the NBA API
    api_url = f"https://api.sportsdata.io/v3/nba/scores/json/GamesByDate/{today_date}?key={api_key}"
    
    try:
        with urllib.request.urlopen(api_url) as response:
            data = json.loads(response.read().decode())
            print(json.dumps(data, indent=4))  # Debugging: log the raw data
    except Exception as e:
        print(f"Error fetching game data from API: {e}")
        return {"statusCode": 500, "body": "Error fetching game data"}
    
    # Loop through each game to fetch additional play-by-play data
    messages = []
    for game in data:
        game_id = game.get("GameID", None)
        if game_id:
            # Fetch play-by-play data
            playbyplay_url = f"https://replay.sportsdata.io/api/v3/nba/pbp/json/playbyplay/{game_id}?key={api_key}"
            try:
                with urllib.request.urlopen(playbyplay_url) as response:
                    playbyplay_data = json.loads(response.read().decode())
            except Exception as e:
                print(f"Error fetching play-by-play data for game {game_id}: {e}")
                playbyplay_data = None

            # Format the game data with play-by-play info
            messages.append(format_game_data(game, playbyplay_data))

    # Final message to be sent
    final_message = "\n---\n".join(messages) if messages else "No games available for today."
    
    # Publish to SNS
    try:
        sns_client.publish(
            TopicArn=sns_topic_arn,
            Message=final_message,
            Subject="NBA Game Updates"
        )
        print("Message published to SNS successfully.")
    except Exception as e:
        print(f"Error publishing to SNS: {e}")
        return {"statusCode": 500, "body": "Error publishing to SNS"}
    
    return {"statusCode": 200, "body": "Data processed and sent to SNS"}
