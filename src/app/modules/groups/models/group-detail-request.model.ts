export class GroupDetailRequest {
  current_user_id: string
  current_group_id: number 

  constructor(current_user_id: string, current_group_id: number) {
    this.current_user_id = current_user_id
    this.current_group_id = current_group_id
  }
}