/*
   GNUstep ProjectCenter - http://www.gnustep.org

   Copyright (C) 2001 Free Software Foundation

   Author: Philippe C.D. Robert <probert@siggraph.org>

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   $Id$
*/

#include "PCLogController.h"

@implementation PCLogController

- (void)logMessage:(NSString *)message tag:(int)tag;
{
    NSString *_log;

    switch (tag) 
    {
        case 0:
            _log = [NSString stringWithFormat:@"Information from <%@: %x - %x>: %@",[self class],self,[NSThread currentThread],message];
            break;

        case 1:
            _log = [NSString stringWithFormat:@"Warning from <%@: %x - %x>: %@",[self class],self,[NSThread currentThread],message];
            break;

        default:
            break;
    }
    
    // Later we redirect this to our own output.
    NSLog(message);
}

@end
