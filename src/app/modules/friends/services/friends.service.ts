import { Injectable } from '@angular/core';
import { SupabaseClient } from '@supabase/supabase-js';
import { Observable, from, map, takeWhile, switchMap } from 'rxjs';
import { Profile, SupabaseService } from 'src/app/core/supabase.service';
import { FriendRequest, FriendRequestStatus } from '../models/friend-request.model';
import { SendFriendRequest } from '../models/send-friend-request.model';

@Injectable({
  providedIn: 'root'
})
export class FriendsService {

  private supabase: SupabaseClient
  constructor(private readonly supabaseService: SupabaseService) {
    this.supabase = this.supabaseService.getClient()
  }

  getUserFriends(userId: string): Observable<Array<Profile> | null> {
    return from(this.supabase
      .from('friends')
      .select('friend_id')
      .eq('user_id', userId)).pipe(
        map(response => response.data),
        takeWhile(data => !!data),
        switchMap(data => {
          const friendIds = data!.map((member) => member.friend_id)
          return this.supabase
            .from('profiles')
            .select('*')
            .in('id', friendIds)
        }),
        map(response => response.data as Array<Profile>)
      )
  }

  sendFriendRequest(body: SendFriendRequest): Observable<any> {
    return from(this.supabase.from('friend_requests').insert(body)).pipe(
      map(response => response.data)
    )
  }

  getUserFriendRequests(userId: string): Observable<Array<FriendRequest>> {
    return from(this.supabase
      .rpc('get_friend_requests', {
        session_user_id: userId
      })
    ).pipe(
      map(response => response.data as Array<FriendRequest>)
    )
  }

  updateFriendRequest(requestId: number, status: FriendRequestStatus): Observable<any> {
    return from(this.supabase
      .from('friend_requests')
      .update({ status})
      .eq('id', requestId)
    ).pipe(
      map(response => response.data)
    )
  }

  deleteFriend(friendId: string): Observable<any> {
    return from(this.supabase
      .from('friends')
      .delete()
      .eq('friend_id', friendId)
    ).pipe(
      map(response => response.data)
    )
  }
}
