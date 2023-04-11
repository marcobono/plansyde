import { Component, Inject } from '@angular/core';
import { MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { FriendRequest, FriendRequestStatus } from '../../models/friend-request.model';
import { FriendsService } from '../../services/friends.service';

@Component({
  selector: 'app-friend-requests',
  templateUrl: './friend-requests.component.html',
  styleUrls: ['./friend-requests.component.scss']
})
export class FriendRequestsComponent {

  reloadRequestsOnClose = false

  constructor(
    private readonly friendService: FriendsService,
    @Inject(MAT_DIALOG_DATA) protected readonly data: {requests: Array<FriendRequest>},
    public dialogRef: MatDialogRef<FriendRequestsComponent>
  ) {}
  
  updateFriendRequest(requestId: number, status: FriendRequestStatus): void {
    this.friendService.updateFriendRequest(requestId, status).subscribe({
      next: () => {
        this.reloadRequestsOnClose = true
        this.hideRequest(requestId)
        if (this.data.requests.length === 0) {
          this.closeDialog()
        }
      }, 
      error: (error) => {
        console.log(error)
        throw error
      }
    })
  }

  private hideRequest(id: number): void {
    this.data.requests = this.data.requests.filter(request => request.request_id != id)
  }

  closeDialog(): void {
    this.dialogRef.close(this.reloadRequestsOnClose)
  }
}
