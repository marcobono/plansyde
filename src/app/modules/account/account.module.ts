import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule, ReactiveFormsModule } from '@angular/forms';
import { RouterModule } from '@angular/router';
import { AccountComponent } from './pages/account/account.component';
import { SharedModule } from '../shared/shared.module';
import { AccountRoutingModule } from './account-routing.module';

@NgModule({
  declarations: [
    AccountComponent
  ],
  imports: [
    CommonModule,
    FormsModule,
    ReactiveFormsModule,
    AccountRoutingModule,
    RouterModule,
    SharedModule
  ]
})
export class AccountModule {}
