export type Invitation = {
  id: number
  groupId: number,
  groupName: string,
  status: string
}

export type InvitationStatus = 'pending' | 'accepted' | 'rejected'