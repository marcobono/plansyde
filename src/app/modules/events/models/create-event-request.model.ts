export class CreateEventRequest {
  name: string
  description: string
  creator_id: string
  group_id: number
  start: Date

  constructor(  
    name: string,
    description: string,
    creator_id: string,
    group_id: number,
    start: Date) {
      this.name = name
      this.description = description
      this.creator_id = creator_id
      this.group_id = group_id
      this.start = start
    }
}