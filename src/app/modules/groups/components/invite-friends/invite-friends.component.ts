import { Component, Inject } from '@angular/core';
import { MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { Profile } from 'src/app/core/supabase.service';
import { SendInvitationRequest } from '../../models/send-invitation-request.model';
import { GroupsService } from '../../services/groups.service';
import { MatSnackBar } from '@angular/material/snack-bar';

@Component({
  selector: 'app-invite-friends',
  templateUrl: './invite-friends.component.html',
  styleUrls: ['./invite-friends.component.scss']
})
export class InviteFriendsComponent {
  reloadRequestsOnClose = false

  constructor(
    private readonly groupService: GroupsService,
    @Inject(MAT_DIALOG_DATA) protected readonly data: {
      friends: Array<Profile & {selected: boolean}>
      groupId: number
      userId: string  
    },
    public dialogRef: MatDialogRef<InviteFriendsComponent>,
    private readonly _snackBar: MatSnackBar
  ) {}

  get selectedFriends(): Array<Profile & {selected: boolean}> {
    return this.data.friends.filter(friend => friend.selected)
  }

  closeDialog(): void {
    this.dialogRef.close(this.reloadRequestsOnClose)
  }

  noFriendSelected(): boolean {
    return this.data.friends.every(friend => !friend.selected)
  }

  inviteSelectedFriends(): void {
    const body = this.selectedFriends.map(friend => (
      new SendInvitationRequest(
        this.data.groupId,
        this.data.userId,
        friend.id
      )
    ))
    this.groupService.sendMultipleInvitations(body).subscribe({
      next: () => {
        this.reloadRequestsOnClose = true
        this.openSnackBar('L\'invito al gruppo è stato inviato', '👍')
        this.closeDialog()
      },
      error: () => {
        this.openSnackBar('Si è verificato un errore', '😵')
        this.closeDialog()
      }
    })
  }

  openSnackBar(message: string, action: string) {
    this._snackBar.open(message, action, {
      duration: 5000,
      horizontalPosition: 'center',
      verticalPosition: 'top'
    });
  }
}
