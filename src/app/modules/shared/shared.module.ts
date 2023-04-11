import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AvatarComponent } from './components/avatar/avatar.component';
import { MatDialogModule } from '@angular/material/dialog';
import {MatDatepickerModule} from '@angular/material/datepicker'
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import {MatProgressSpinnerModule} from '@angular/material/progress-spinner';
import {MatSnackBarModule} from '@angular/material/snack-bar';

@NgModule({
  declarations: [
    AvatarComponent
  ],
  imports: [
    CommonModule,
    MatDialogModule,
    MatDatepickerModule,
    MatProgressSpinnerModule,
    MatSnackBarModule,
    ReactiveFormsModule,
    FormsModule
  ],
  exports: [
    AvatarComponent,
    MatDatepickerModule,
    MatProgressSpinnerModule,
    MatSnackBarModule
  ]
})
export class SharedModule { }
