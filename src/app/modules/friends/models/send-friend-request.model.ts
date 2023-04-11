export class SendFriendRequest {

  user_id: string
  friend_id: string

  constructor(user_id: string, friend_id: string) {
    this.user_id = user_id
    this.friend_id = friend_id
  }
}