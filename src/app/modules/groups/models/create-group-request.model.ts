export class CreateGroupRequest {
  name: string
  description: string
  creator_id: string
  constructor(name: string, description: string, creator_id: string) {
    this.name = name
    this.description = description
    this.creator_id = creator_id
  }
}