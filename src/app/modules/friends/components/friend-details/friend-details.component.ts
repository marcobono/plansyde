import { Component, Inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { Profile } from 'src/app/core/supabase.service';
import { FriendRequestsComponent } from '../../pages/friend-requests/friend-requests.component';
import { FriendsService } from '../../services/friends.service';
import { timer } from 'rxjs';

@Component({
  selector: 'app-friend-details',
  templateUrl: './friend-details.component.html',
  styleUrls: ['./friend-details.component.scss']
})
export class FriendDetailsComponent {

  reloadOnClose = false
  deleteConfirm: boolean = false

  constructor(
    private readonly friendService: FriendsService,
    @Inject(MAT_DIALOG_DATA) protected readonly data: {friend: Profile},
    public dialogRef: MatDialogRef<FriendRequestsComponent>
  ) {}

  setDeleteConfirm(): void {
    this.deleteConfirm = true
    timer(3000).subscribe(() => this.deleteConfirm = false)
  }

  deleteFriend(): void {
    this.friendService.deleteFriend(this.data.friend.id!).subscribe({
      next: () => {
        this.reloadOnClose = true
        this.closeDialog()
      },
      error: (error) => {
        throw error
      }
    })
  }

  closeDialog(): void {
    this.dialogRef.close(this.reloadOnClose)
  }

}
