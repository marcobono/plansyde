import { Injectable } from '@angular/core';
import { SupabaseClient } from '@supabase/supabase-js';
import { Observable, from, map, switchMap, takeWhile } from 'rxjs';
import { SupabaseService } from 'src/app/core/supabase.service';
import { CreateGroupRequest } from '../models/create-group-request.model';
import { GroupDetailRequest } from '../models/group-detail-request.model';
import { GroupDetail } from '../models/group-detail.model';
import { Group } from '../models/group.model';
import { InvitationGroupInfo } from '../models/invitation-group-info.model';
import { InvitationStatus } from '../models/invitation.model';
import { SendInvitationRequest } from '../models/send-invitation-request.model';
import { LeaveGroupRequestModel } from '../models/leave-group-request.model';

@Injectable({
  providedIn: 'root'
})
export class GroupsService {

  private supabase: SupabaseClient
  constructor(private readonly supabaseService: SupabaseService) {
    this.supabase = this.supabaseService.getClient()
  }

  getGroupById(id: number): Observable<any> {
    return from(this.supabase
      .from('groups')
      .select('id')
      .eq('id', id)
    ).pipe(
      takeWhile(response => !!response.data),
      map(response => response.data)
    )
  }

  createGroup(groupData: CreateGroupRequest): Observable<any> {
    return from(this.supabase.from('groups').insert(groupData)).pipe(
      map(response => response.data)
    )
  }

  getUserGroups(userId: string): Observable<Array<Group> | null> {
    return from(this.supabase
      .from('members')
      .select('group_id')
      .eq('user_id', userId)).pipe(
        map(response => response.data),
        takeWhile(data => !!data),
        switchMap(data => {
          const groupIds = data!.map((member) => member.group_id)
          return this.supabase
            .from('groups')
            .select('*')
            .in('id', groupIds)
        }),
        map(response => response.data as Array<Group>)
      )
  }

  sendInvitation(body: SendInvitationRequest): Observable<any> {
    return from(this.supabase
      .from('invitations')
      .insert([ body ])
    )
  }

  sendMultipleInvitations(body: SendInvitationRequest[]): Observable<any> {
    return from(this.supabase
      .from('invitations')
      .insert(body)
    )
  }

  getUserInvitationAndGroupInfo(userId: string): Observable<Array<InvitationGroupInfo>> {
    return from(this.supabase
      .rpc('get_user_invitations_with_group_info', {current_user_id: userId})
    ).pipe(
      map(response => response.data as Array<InvitationGroupInfo>)
    )
  }

  updateInvitation(requestId: number, status: InvitationStatus): Observable<any> {
    return from(this.supabase
      .from('invitations')
      .update({status})
      .eq('id', requestId)
    ).pipe(
      map(response => response.data)
    )
  }

  getGroupInfo(body: GroupDetailRequest): Observable<GroupDetail> {
    return from(this.supabase
      .rpc('get_group_info', body)
    ).pipe(
      map(response => response.data[0] as GroupDetail)
    )
  }

  leaveGroup(body: LeaveGroupRequestModel): Observable<any> {
    return from(this.supabase
      .from('members')
      .delete()
      .eq('user_id', body.user_id)
      .eq('group_id', body.group_id)
    )
  }


}
