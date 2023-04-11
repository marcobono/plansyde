import { Component, Inject } from '@angular/core';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { InvitationGroupInfo } from '../../models/invitation-group-info.model';
import { InvitationStatus } from '../../models/invitation.model';
import { GroupsService } from '../../services/groups.service';

@Component({
  selector: 'app-invitations',
  templateUrl: './invitations.component.html',
  styleUrls: ['./invitations.component.scss']
})
export class InvitationsComponent {
  
  reloadRequestsOnClose = false

  constructor(
    private readonly groupService: GroupsService,
    @Inject(MAT_DIALOG_DATA) protected readonly data: {
      invitations: Array<InvitationGroupInfo> 
    },
    public dialogRef: MatDialogRef<InvitationsComponent>
  ) {}

  updateInvitation(invitationId: number, status: InvitationStatus): void {
    this.groupService.updateInvitation(invitationId, status).subscribe({
      next: () => {
        this.reloadRequestsOnClose = true
        this.hideRequest(invitationId)
        if (this.data.invitations.length === 0) {
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
    this.data.invitations = this.data.invitations.filter(invitation => invitation.id != id)
  }

  closeDialog(): void {
    this.dialogRef.close(this.reloadRequestsOnClose)
  }
}
