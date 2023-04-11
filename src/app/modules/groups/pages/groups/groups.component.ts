import { Component, OnInit } from '@angular/core';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MatDialog } from '@angular/material/dialog';
import { Router } from '@angular/router';
import { map, switchMap } from 'rxjs';
import { SupabaseService } from 'src/app/core/supabase.service';
import { CreateGroupRequest } from '../../models/create-group-request.model';
import { Group } from '../../models/group.model';
import { InvitationGroupInfo } from '../../models/invitation-group-info.model';
import { GroupsService } from '../../services/groups.service';
import { InvitationsComponent } from '../../components/invitations/invitations.component';
import { MatSnackBar } from '@angular/material/snack-bar';

@Component({
  selector: 'app-groups',
  templateUrl: './groups.component.html',
  styleUrls: ['./groups.component.scss']
})
export class GroupsComponent implements OnInit {

  constructor(private readonly formBuilder: FormBuilder,
    private readonly supabase: SupabaseService,
    private readonly groupService: GroupsService,
    private readonly router: Router,
    private readonly dialog: MatDialog,
    private readonly _snackBar: MatSnackBar
    ) {
  }

  loading = false
  showForm: boolean = false;
  groups: Array<Group>
  invitations: Array<InvitationGroupInfo>
  nameControlMaxLenght: 20;
  descriptionControlMaxLenght: 140;
  form: FormGroup

  ngOnInit(): void {
    this.createForm()
    this.fetchUserGroups()
    this.fetchUserInvitations()
  }

  createForm(): void {
    this.form = this.formBuilder.group({
      name: ['', [Validators.required, Validators.maxLength(this.nameControlMaxLenght)]],
      description: ['', [Validators.required, Validators.maxLength(this.descriptionControlMaxLenght)]]
    })
  }

  createGroup(): void {
    this.supabase.session.pipe(
      map(session => session!.user),
      switchMap(user => {
        const groupData = new CreateGroupRequest(
          this.form.value.name,
          this.form.value.description,
          user.id
        );
        return this.groupService.createGroup(groupData)
      })
    ).subscribe({
      next: () => {
        this.form.reset()
        this.showForm = false
        this.openSnackBar('Gruppo creato', '👍')
        this.fetchUserGroups()
        this.fetchUserInvitations()
      },
      error: () => {
        this.openSnackBar('Si è verificato un errore', '😵')
      }
    });
  }

  fetchUserGroups(): void {
    this.loading = true
    this.supabase.session.pipe(
      map(session => session!.user),
      switchMap(user => {
        return this.groupService.getUserGroups(user.id)
      })
    ).subscribe({
      next: (data) => {
        this.loading = false;
        this.groups = data!
      },
      error: () => {
        this.openSnackBar('Si è verificato un errore', '😵')
      }
    })
  }

  private fetchUserInvitations(): void {
    this.supabase.session.pipe(
      map(session => session!.user),
      switchMap(user => {
        return this.groupService.getUserInvitationAndGroupInfo(user.id)
      })
    ).subscribe({ 
      next: (data) => {
        this.invitations = data!
      },
      error: () => {
        this.openSnackBar('Si è verificato un errore', '😵')
      }
    })
  }

  goToGroupDetail(id: number): void {
    this.router.navigateByUrl(`/groups/${id}`)
  }

  openDialog(): void {
    const dialogRef = this.dialog.open(InvitationsComponent, {
      width: '90vw', maxWidth: '90vw',
      data: { invitations: this.invitations}
    });
  
    dialogRef.afterClosed().subscribe((reloadRequests: boolean) => {
      if (reloadRequests) {
        this.fetchUserGroups()
        this.fetchUserInvitations()
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
