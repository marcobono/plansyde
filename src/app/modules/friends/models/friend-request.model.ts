export type FriendRequest = {
  request_id: number
  sender_profile: {
    id: string
    full_name: string
    username: string
    num_friends: number
  }
}

export type FriendRequestStatus = 'pending' | 'accepted' | 'rejected'