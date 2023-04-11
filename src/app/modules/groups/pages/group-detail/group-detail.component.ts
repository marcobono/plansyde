import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MatDialog } from '@angular/material/dialog';
import { ActivatedRoute } from '@angular/router';
import { map, switchMap, zip } from 'rxjs';
import { Profile, SupabaseService } from 'src/app/core/supabase.service';
import { OngoingEvent } from 'src/app/modules/events/models/event.model';
import { maxUsernameLength, minUsernameLength } from 'src/app/modules/shared/consts/username-config.const';
import { UsersService } from 'src/app/modules/shared/services/users.service';
import { CreateEventComponent } from '../../components/create-event/create-event.component';
import { InviteFriendsComponent } from '../../components/invite-friends/invite-friends.component';
import { GroupDetailRequest } from '../../models/group-detail-request.model';
import { GroupDetail, GroupInfo } from '../../models/group-detail.model';
import { SendInvitationRequest } from '../../models/send-invitation-request.model';
import { GroupsService } from '../../services/groups.service';
import { GroupSettingsComponent } from '../../components/group-settings/group-settings.component';
import { MatSnackBar } from '@angular/material/snack-bar';

@Component({
  selector: 'app-group-detail',
  templateUrl: './group-detail.component.html',
  styleUrls: ['./group-detail.component.scss']
})
export class GroupDetailComponent implements OnInit {

  loading = false
  form: FormGroup
  groupDetails: GroupDetail
  info: GroupInfo
  friendsNotInGroup: Array<Profile>
  members: Array<Profile>
  events: Array<OngoingEvent>
  maxUsernameLength: number = maxUsernameLength
  minUsernameLength: number = minUsernameLength
  showForm: boolean = false;

  constructor(
    private readonly route: ActivatedRoute,
    private readonly groupService: GroupsService,
    private readonly userService: UsersService,
    private readonly supabase: SupabaseService ,
    private readonly formBuilder: FormBuilder,
    private readonly dialog: MatDialog,
    private readonly _snackBar: MatSnackBar
  ) {}

  ngOnInit(): void {
    this.createForm()
    this.fetchGroupDetails()
  }

  private createForm(): void {
    this.form = this.formBuilder.group({
      name: ['', [
        Validators.required,
        Validators.maxLength(20)
      ]],
      description : ['', Validators.maxLength(140)]
    })
  }

  private fetchGroupDetails(): void {
    this.loading = true
    const groupIdParam = +this.route.snapshot.params['id']
    this.supabase.session.pipe(
      switchMap((session) => {
        const { user } = session!
        const body = new GroupDetailRequest(
          user.id, groupIdParam
        )
        return this.groupService.getGroupInfo(body)
      })
    ).subscribe({
      next: (data) => {
        this.loading = false
        this.info = data.group_info[0]
        this.events = data.events
        this.members = data.members
        this.friendsNotInGroup = data.friends_not_in_group
      },
      error: () => {
        this.loading = false
        this.openSnackBar('Si è verificato un errore', '😵')
      }
    })

  }

  openAddFriendsDialog(): void {
    this.supabase.session.subscribe({
      next: (session) => {
        const { user } = session!
        const dialogData = this.friendsNotInGroup.slice().map(friend => ({...friend, selected: false}))
        const dialogRef = this.dialog.open(InviteFriendsComponent, {
          width: '90vw', maxWidth: '90vw',
          data: { 
            friends: dialogData,
            groupId: this.route.snapshot.params['id'],
            userId: user.id
          }
        });
        dialogRef.afterClosed().subscribe((reload: boolean) => {
          if (reload) {
            this.fetchGroupDetails()
          }
        });
      }
    })
  }

  openCreateEventDialog(): void {
    this.supabase.session.subscribe({
      next: (session) => {
        const { user } = session!
        const {name, description} = this.form.value
        const dialogRef = this.dialog.open(CreateEventComponent, {
          width: '90vw', maxWidth: '90vw',
          data: {
            groupId: this.route.snapshot.params['id'],
            userId: user.id,
            name, description
          }
        });
        dialogRef.afterClosed().subscribe((reload: boolean) => {
          if (reload) {
            this.showForm = false
            this.form.reset()
            this.fetchGroupDetails()
          }
        });
      }
    })
  }

  openGroupSettingsDialog(): void {
    this.dialog.open(GroupSettingsComponent, {
      width: '90vw', maxWidth: '90vw',
      data: {
        groupInfo: this.info,
        members: this.members
      }
    });
  }

  openSnackBar(message: string, action: string) {
    this._snackBar.open(message, action, {
      duration: 5000,
      horizontalPosition: 'center',
      verticalPosition: 'top'
    });
  }
}
