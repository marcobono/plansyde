import { Component, Inject } from '@angular/core';
import { GroupInfo } from '../../models/group-detail.model';
import { MAT_DIALOG_DATA, MatDialogRef } from '@angular/material/dialog';
import { GroupsService } from '../../services/groups.service';
import { Profile, SupabaseService } from 'src/app/core/supabase.service';
import { switchMap, timer } from 'rxjs';
import { Router } from '@angular/router';
import { LeaveGroupRequestModel } from '../../models/leave-group-request.model';

@Component({
  selector: 'app-group-settings',
  templateUrl: './group-settings.component.html',
  styleUrls: ['./group-settings.component.scss']
})
export class GroupSettingsComponent {

  abandonConfirm: boolean = false

  constructor(
    private readonly groupService: GroupsService,
    private readonly supabase: SupabaseService,
    private readonly router: Router,
    @Inject(MAT_DIALOG_DATA) protected readonly data: {
      groupInfo: GroupInfo,
      members: Array<Profile>
    },
    public dialogRef: MatDialogRef<GroupSettingsComponent>,
  ) {}

  leaveGroup(): void {
    this.supabase.session.pipe(
      switchMap((session) => {
        const { user } = session!
        const body = new LeaveGroupRequestModel(
          user.id,
          this.data.groupInfo.id
        )
        return this.groupService.leaveGroup(body)
      })
    ).subscribe({
      next: () => {
        this.closeDialog()
        this.router.navigateByUrl('/groups')
      },
      error: (error) => {
        throw error
      }
    })
  }

  setAbandonConfirm(): void {
    this.abandonConfirm = true
    timer(3000).subscribe(() => this.abandonConfirm = false)
  }

  closeDialog(): void {
    this.dialogRef.close()
  }

}
