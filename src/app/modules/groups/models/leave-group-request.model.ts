export class LeaveGroupRequestModel {

  user_id: string
  group_id: number

  constructor(
    user_id: string,
    group_id: number
  ) {
    this.user_id = user_id
    this.group_id = group_id
  }
}