export class SendInvitationRequest {

  group_id: number
  inviter_id: string
  invitee_id: string

  constructor(group_id: number, inviter_id: string, invitee_id) {
    this.group_id = group_id
    this.inviter_id = inviter_id
    this.invitee_id = invitee_id
  }
}