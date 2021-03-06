/***
* Name: Corona
* Author: hqngh
* Description: 
* Tags: Tag1, Tag2, TagN
***/


@no_experiment
model Species_Individual

import "../Constants.gaml"
import "../Parameters.gaml"
import "../Functions.gaml"
import "Building.gaml"
import "Activity.gaml"
import "Authority.gaml"

global
{
	int total_number_of_infected <- 0;
	int total_number_reported <- 0;
	int total_number_individual <- 0;
}


species Individual{
	int ageCategory;
	int sex; //0 M 1 F
	bool wearMask;
	Building home;
	Building school;
	Building office;
	list<Individual> relatives;
	Building bound;
	
	
	string status; //S,E,Ua,Us,A,R,D
	string report_status; //Not-tested, Negative, Positive
	float incubation_time; 
	float infectious_time;
	float serial_interval;
	
	
	map<int, Activity> agenda_week;
	Activity last_activity;
	bool free_rider <- false;
	int tick <- 0;
	
	
	action testIndividual
	{
		if(self.is_infected())
		{
			if(flip(probability_true_positive))
			{
				report_status <- tested_positive;
				total_number_reported <- total_number_reported+1;
			}
			else
			{
				report_status <- tested_negative;
			}
		}
		else
		{
			if(flip(probability_true_negative))
			{
				report_status <- tested_negative;
			}
			else
			{
				report_status <- tested_positive;
				total_number_reported <- total_number_reported+1;
			}
		}
	}

	action updateWearMask
	{
		if(free_rider)
		{
			wearMask <- false;
		}
		else
		{
			if(flip(proportion_wearing_mask))
			{
				wearMask <- true;
			}
			else
			{
				wearMask <- false;
			}
		}
	}
	
	action defineNewCase
	{
		total_number_of_infected <- total_number_of_infected +1;
		self.status <- exposed;
		self.incubation_time <- world.get_incubation_time();
		self.serial_interval <- world.get_serial_interval();
		self.infectious_time <- world.get_infectious_time();
		
		
		if(serial_interval<0)
		{
			self.infectious_time <- max(0,self.infectious_time - self.serial_interval);
			self.incubation_time <- max(0,self.incubation_time + self.serial_interval);
		}
		self.tick <- 0;
	}
	
	bool is_infectious {
		return [asymptomatic,symptomatic_without_symptoms, symptomatic_with_symptoms ] contains status;
	}
	
	bool is_exposed {
		return status = exposed;
	}
	
	bool is_infected {
		return self.is_infectious() or self.is_exposed();
	}
	
	bool is_asymptomatic {
		return [asymptomatic,symptomatic_without_symptoms] contains status;
	}

	reflex infectOthers when: self.is_infectious()
	{
		float effective_successful_contact_rate <- successful_contact_rate;
		if(self.is_asymptomatic())
		{
			effective_successful_contact_rate <- effective_successful_contact_rate * factor_contact_rate_asymptomatic;
		}
		if(self.wearMask)
		{
			effective_successful_contact_rate <- effective_successful_contact_rate * factor_contact_rate_wearing_mask;
		}
		ask (Individual where ((flip(effective_successful_contact_rate)) and (each.status = susceptible) and (each.bound = self.bound)))
	 	{
				do defineNewCase;
	 	}
	}
	
	reflex becomeInfectious when: self.is_exposed() and(tick >= incubation_time)
	{
		if(world.is_asymptomatic())
		{
			status <- asymptomatic;
			tick <- 0;
		}
		else
		{
			if(serial_interval<0)
			{
				status <- symptomatic_without_symptoms;
				tick <- 0;
			}
			else
			{
				status <- symptomatic_with_symptoms;
				tick <- 0;
			}
		}
	}
	
	reflex becomeSymptomatic when: (status=symptomatic_without_symptoms) and (tick>=serial_interval)
	{
		status <- symptomatic_with_symptoms;
		do testIndividual();
	}
	
	reflex becomeNotInfectious when: ((status=symptomatic_with_symptoms) or (status=asymptomatic))and(tick>=infectious_time)
	{
		if(status = symptomatic_with_symptoms)
		{
			if(world.is_fatal())
			{
				status <- dead;
			}
			else
			{
				status <- recovered;
			}
		}
		else
		{
			status <- recovered;
		}
	}
	
	
	reflex executeAgenda {
		Activity act <- agenda_week[current_date.hour];
		if (act != nil) {
			last_activity <- act;
			if (Authority[0].allows(self, act)) {
				bound <- any(act.find_target(self));
				location <- any_location_in(bound);
			}
		}
	}

	reflex updateDiseaseCycle when:(status!=recovered)or(status!=dead) {
		tick <- tick + 1;
		do updateWearMask();
	}

	aspect default {
		draw shape color: status = exposed ? #pink : ((status = symptomatic_with_symptoms)or(status=asymptomatic)or(status=symptomatic_without_symptoms)? #red : #green);
	}

}